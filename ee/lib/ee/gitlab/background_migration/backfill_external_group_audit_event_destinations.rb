# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillExternalGroupAuditEventDestinations
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        class AuditEventsExternalAuditEventDestination < ::ApplicationRecord
          self.table_name = 'audit_events_external_audit_event_destinations'
        end

        class GroupExternalStreamingDestination < ::ApplicationRecord
          self.table_name = 'audit_events_group_external_streaming_destinations'
          enum category: { http: 0, gcp: 1, aws: 2 }

          attr_accessor :secret_token

          before_validation :encrypt_secret_token, if: :secret_token

          private

          def encrypt_secret_token
            key = Settings.attr_encrypted_db_key_base_32
            cipher = OpenSSL::Cipher.new('aes-256-gcm')
            cipher.encrypt
            iv = cipher.random_iv
            cipher.key = Digest::SHA256.digest(key)[0...32]
            cipher.iv = iv
            encrypted = cipher.update(secret_token) + cipher.final
            self.encrypted_secret_token = encrypted
            self.encrypted_secret_token_iv = iv
          end
        end

        class GroupEventTypeFilter < ::ApplicationRecord
          self.table_name = 'audit_events_group_streaming_event_type_filters'
        end

        class GroupNamespaceFilter < ::ApplicationRecord
          self.table_name = 'audit_events_streaming_group_namespace_filters'
        end

        class StreamingHeader < ::ApplicationRecord
          self.table_name = 'audit_events_streaming_headers'
        end

        class StreamingEventTypeFilter < ::ApplicationRecord
          self.table_name = 'audit_events_streaming_event_type_filters'
        end

        class StreamingHttpGroupNamespaceFilter < ::ApplicationRecord
          self.table_name = 'audit_events_streaming_http_group_namespace_filters'
        end

        prepended do
          operation_name :backfill_external_group_audit_event_destinations
          feature_category :audit_events
          scope_to ->(relation) do
            relation.where(stream_destination_id: nil)
          end
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
          token = legacy_destination.verification_token
          return unless token

          destination = GroupExternalStreamingDestination.new(
            name: legacy_destination.name,
            category: :http,
            config: build_config(legacy_destination),
            legacy_destination_ref: legacy_destination.id,
            group_id: legacy_destination.namespace_id,
            created_at: legacy_destination.created_at,
            updated_at: legacy_destination.updated_at
          )

          destination.secret_token = token
          destination.save!
          destination
        end

        def build_config(legacy_destination)
          headers = StreamingHeader.where(
            external_audit_event_destination_id: legacy_destination.id,
            group_id: legacy_destination.namespace_id
          ).pluck(:key, :value, :active)

          header_config = {
            'X-Gitlab-Event-Streaming-Token' => {
              'value' => legacy_destination.verification_token,
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
          }.to_json
        end

        def copy_event_type_filters(source, destination)
          filters = StreamingEventTypeFilter.where(
            external_audit_event_destination_id: source.id,
            group_id: source.namespace_id
          ).pluck(:audit_event_type, :created_at, :updated_at)

          return if filters.empty?

          attributes = filters.map do |audit_event_type, created_at, updated_at|
            {
              audit_event_type: audit_event_type,
              created_at: created_at,
              updated_at: updated_at,
              external_streaming_destination_id: destination.id,
              namespace_id: source.namespace_id
            }
          end

          GroupEventTypeFilter.insert_all!(attributes)
        end

        def copy_namespace_filter(source, destination)
          filter = StreamingHttpGroupNamespaceFilter.find_by(
            external_audit_event_destination_id: source.id
          )

          return unless filter

          GroupNamespaceFilter.create!(
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
