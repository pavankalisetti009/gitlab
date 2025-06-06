# frozen_string_literal: true

module AuditEvents
  module LegacyDestinationSyncHelper
    include AuditEvents::DestinationSyncValidator

    STREAMING_TOKEN_HEADER_KEY = 'X-Gitlab-Event-Streaming-Token'

    def create_stream_destination(legacy_destination_model:, category:, is_instance:)
      return unless legacy_destination_sync_enabled?(legacy_destination_model, is_instance)

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

        legacy_destination_model.update!(stream_destination_id: destination.id)
        destination
      end

    rescue ActiveRecord::RecordInvalid, StandardError => e
      Gitlab::ErrorTracking.track_exception(e, audit_event_destination_model: legacy_destination_model.class.name)
      nil
    end

    def update_stream_destination(legacy_destination_model:)
      is_instance = !legacy_destination_model.respond_to?(:group)
      return unless legacy_destination_sync_enabled?(legacy_destination_model, is_instance)

      stream_destination = legacy_destination_model.stream_destination

      return if stream_destination.nil? || stream_destination.legacy_destination_ref != legacy_destination_model.id

      category = stream_destination.category.to_sym

      ApplicationRecord.transaction do
        stream_destination.update!(
          name: legacy_destination_model.name,
          category: category,
          config: build_streaming_config(legacy_destination_model, category),
          secret_token: secret_token(legacy_destination_model, category)
        )

        stream_destination
      end
    rescue ActiveRecord::RecordInvalid, StandardError => e
      Gitlab::ErrorTracking.track_exception(e, audit_event_destination_model: legacy_destination_model.class.name)
      nil
    end

    private

    def build_streaming_config(legacy_destination_model, category)
      case category
      when :http
        all_headers = {}

        all_headers[STREAMING_TOKEN_HEADER_KEY] = {
          'value' => legacy_destination_model.verification_token,
          'active' => true
        }

        if legacy_destination_model.respond_to?(:headers)
          legacy_destination_model.headers.each do |header|
            all_headers[header.key] = {
              'value' => header.value,
              'active' => header.active
            }
          end
        end

        {
          'url' => legacy_destination_model.destination_url,
          'headers' => all_headers
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

    def secret_token(model, category)
      case category
      when :http then model.verification_token
      when :aws then model.secret_access_key
      when :gcp then model.private_key
      end
    end
  end
end
