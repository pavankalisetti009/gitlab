# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillExternalInstanceAuditEventDestinationsFixed
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        class AuditEventsExternalAuditEventDestination < ::ApplicationRecord
          self.table_name = 'audit_events_instance_external_audit_event_destinations'
        end

        class InstanceExternalStreamingDestination < ::ApplicationRecord
          self.table_name = 'audit_events_instance_external_streaming_destinations'
          enum category: { http: 0, gcp: 1, aws: 2 }
        end

        class InstanceEventTypeFilter < ::ApplicationRecord
          self.table_name = 'audit_events_instance_streaming_event_type_filters'
        end

        class InstanceNamespaceFilter < ::ApplicationRecord
          self.table_name = 'audit_events_streaming_instance_namespace_filters'
        end

        class StreamingHeader < ::ApplicationRecord
          self.table_name = 'instance_audit_events_streaming_headers'
        end

        class StreamingEventTypeFilter < ::ApplicationRecord
          self.table_name = 'audit_events_streaming_instance_event_type_filters'
        end

        class StreamingHttpInstanceNamespaceFilter < ::ApplicationRecord
          self.table_name = 'audit_events_streaming_http_instance_namespace_filters'
        end

        prepended do
          operation_name :backfill_external_instance_audit_event_destinations
          feature_category :audit_events
          scope_to ->(relation) { relation.where(stream_destination_id: nil) }
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            process_batch(sub_batch)
          end
        end

        private

        def process_batch(sub_batch)
          sub_batch.each do |legacy_destination|
            ApplicationRecord.transaction do
              destination = create_streaming_destination(legacy_destination)
              next unless destination

              copy_event_type_filters(legacy_destination, destination)
              copy_namespace_filter(legacy_destination, destination)
              update_legacy_record(legacy_destination, destination)
            end
          end
        end

        def create_streaming_destination(legacy_destination)
          encrypted_token, encrypted_iv = AuditEventsExternalAuditEventDestination
            .where(id: legacy_destination.id)
            .pick(:encrypted_verification_token, :encrypted_verification_token_iv)

          return unless encrypted_token.present?

          token_for_config = get_verification_token(legacy_destination.id)
          return unless token_for_config

          destination = InstanceExternalStreamingDestination.new(
            name: legacy_destination.name,
            category: :http,
            config: build_config(legacy_destination, token_for_config),
            legacy_destination_ref: legacy_destination.id,
            created_at: legacy_destination.created_at,
            updated_at: legacy_destination.updated_at
          )

          destination.encrypted_secret_token = encrypted_token
          destination.encrypted_secret_token_iv = encrypted_iv

          destination.save!(validate: false)
          destination
        end

        def get_verification_token(destination_id)
          model_class = ::AuditEvents::InstanceExternalAuditEventDestination
          legacy_model = model_class.find_by(id: destination_id)
          legacy_model&.verification_token
        end

        def build_config(legacy_destination, token)
          headers = StreamingHeader.where(
            instance_external_audit_event_destination_id: legacy_destination.id
          ).pluck(:key, :value, :active)

          header_config = {
            'X-Gitlab-Event-Streaming-Token' => {
              'value' => token,
              'active' => true
            }
          }

          headers.each do |key, value, active|
            header_config[key] = {
              'value' => value,
              'active' => active
            }
          end

          {
            'url' => legacy_destination.destination_url,
            'headers' => header_config
          }
        end

        def copy_event_type_filters(source, destination)
          filters = StreamingEventTypeFilter.where(
            instance_external_audit_event_destination_id: source.id
          ).pluck(:audit_event_type, :created_at, :updated_at)

          return if filters.empty?

          attributes = filters.map do |audit_event_type, created_at, updated_at|
            {
              audit_event_type: audit_event_type,
              created_at: created_at,
              updated_at: updated_at,
              external_streaming_destination_id: destination.id
            }
          end

          InstanceEventTypeFilter.insert_all!(attributes)
        end

        def copy_namespace_filter(source, destination)
          filter = StreamingHttpInstanceNamespaceFilter.find_by(
            audit_events_instance_external_audit_event_destination_id: source.id
          )

          return unless filter

          InstanceNamespaceFilter.create!(
            namespace_id: filter.namespace_id,
            external_streaming_destination_id: destination.id,
            created_at: filter.created_at,
            updated_at: filter.updated_at
          )
        end

        def update_legacy_record(source, destination)
          source.update!(stream_destination_id: destination.id)
        end
      end
    end
  end
end
