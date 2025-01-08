# frozen_string_literal: true

module AuditEvents
  module LegacyDestinationSyncHelper
    include Gitlab::Utils::StrongMemoize

    CreateError = Class.new(StandardError)

    STREAMING_TOKEN_HEADER_KEY = 'X-Gitlab-Event-Streaming-Token'

    def create_stream_destination(legacy_destination_model:, category:, is_instance:)
      return unless legacy_destination_sync_enabled?

      model_class = if is_instance
                      AuditEvents::Instance::ExternalStreamingDestination
                    else
                      AuditEvents::Group::ExternalStreamingDestination
                    end

      ApplicationRecord.transaction do
        destination = model_class.new(
          name: legacy_destination_model.name,
          category: category,
          config: build_streaming_config(legacy_destination_model, category),
          secret_token: secret_token(legacy_destination_model, category),
          legacy_destination_ref: legacy_destination_model.id
        )
        destination.group = legacy_destination_model.group unless is_instance

        destination.save!

        copy_event_type_filters(legacy_destination_model, destination)
        copy_namespace_filters(legacy_destination_model, destination)

        legacy_destination_model.update!(stream_destination_id: destination.id)
        destination
      end

    rescue ActiveRecord::RecordInvalid, CreateError => e
      Gitlab::ErrorTracking.track_exception(e, audit_event_destination_model: legacy_destination_model.class.name)
      nil
    end

    private

    def legacy_destination_sync_enabled?
      Feature.enabled?(:audit_events_external_destination_streamer_consolidation_refactor, :instance)
    end

    def audit_event_namespace(destination)
      destination.instance_level? ? 'AuditEvents::Instance' : 'AuditEvents::Group'
    end

    def copy_event_type_filters(source, destination)
      return unless source.respond_to?(:event_type_filters)

      source.event_type_filters.find_each do |filter|
        filter_class = "#{audit_event_namespace(destination)}::EventTypeFilter".constantize

        attributes = {
          audit_event_type: filter.audit_event_type,
          external_streaming_destination: destination
        }

        attributes[:namespace] = destination.group unless destination.instance_level?

        filter_class.create!(attributes)
      end
    end

    def copy_namespace_filters(source, destination)
      return unless source.respond_to?(:namespace_filter)
      return unless source.namespace_filter

      filter_class = "#{audit_event_namespace(destination)}::NamespaceFilter".constantize

      filter_class.create!(
        namespace: source.namespace_filter.namespace,
        external_streaming_destination: destination
      )
    end

    def build_streaming_config(legacy_destination_model, category)
      case category
      when :http
        {
          'url' => legacy_destination_model.destination_url,
          'headers' => build_headers_config(legacy_destination_model)
        }
      when :aws
        {
          'accessKeyXid' => legacy_destination_model.access_key_xid,
          'bucketName' => legacy_destination_model.bucket_name,
          'awsRegion' => legacy_destination_model.aws_region
        }
      when :gcp
        {
          'googleProjectIdName' => legacy_destination_model.google_project_id_name,
          'logIdName' => legacy_destination_model.log_id_name || 'audit-events',
          'clientEmail' => legacy_destination_model.client_email
        }
      end
    end

    def build_headers_config(legacy_destination_model)
      base_headers = {
        STREAMING_TOKEN_HEADER_KEY => {
          'value' => legacy_destination_model.verification_token,
          'active' => true
        }
      }

      return base_headers unless legacy_destination_model.respond_to?(:headers)

      headers = legacy_destination_model.headers

      headers.active.each_with_object(base_headers) do |header, hash|
        hash[header.key] = {
          'value' => header.value,
          'active' => header.active
        }
      end
    end

    def secret_token(model, category)
      case category
      when :http then model.verification_token
      when :aws then model.secret_access_key
      when :gcp then model.private_key
      end
    end
  end
end
