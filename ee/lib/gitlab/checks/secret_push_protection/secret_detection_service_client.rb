# frozen_string_literal: true

module Gitlab
  module Checks
    module SecretPushProtection
      class SecretDetectionServiceClient
        include ::Gitlab::Loggable

        LOG_MESSAGES = {
          sds_disabled: "SDS is disabled: FF: %{sds_ff_enabled}, SaaS: %{saas_feature_enabled}, " \
            "Non-Dedicated: %{is_not_dedicated}"
        }.freeze

        def initialize(project:)
          @project = project
          @sds_client = nil

          settings = ::Gitlab::CurrentSettings.current_application_settings
          @sds_host = settings.secret_detection_service_url
          @sds_auth_token = settings.secret_detection_service_auth_token

          @is_dedicated = settings.gitlab_dedicated_instance
          @should_use_sds = nil
        end

        # Determines if SDS should be used (feature flags + instance checks).
        def use_secret_detection_service?
          return @should_use_sds unless @should_use_sds.nil?

          sds_ff_enabled = Feature.enabled?(:use_secret_detection_service, project)
          saas_feature_enabled = ::Gitlab::Saas.feature_available?(:secret_detection_service)
          is_not_dedicated = !@is_dedicated

          @should_use_sds = sds_ff_enabled && saas_feature_enabled && is_not_dedicated

          unless @should_use_sds
            msg = format(LOG_MESSAGES[:sds_disabled], { sds_ff_enabled:, saas_feature_enabled:, is_not_dedicated: })
            secret_detection_logger.info(build_structured_payload(message: msg))
          end

          @should_use_sds
        end

        # Send payloads to SDS asynchronously or directly (ignores response).
        def send_request_to_sds(payloads, exclusions: {})
          setup_sds_client
          return if sds_client.nil?

          request = build_sds_request(payloads, exclusions: exclusions)

          # ignore the response for now
          _ = sds_client.run_scan(request: request, auth_token: sds_auth_token)
        rescue StandardError => e
          ::Gitlab::ErrorTracking.track_exception(e)
        end

        private

        attr_accessor :sds_client, :sds_auth_token, :sds_host, :is_dedicated, :project

        def setup_sds_client
          return unless use_secret_detection_service?
          return if sds_client.present?
          return if sds_host.blank?

          begin
            @sds_client = ::Gitlab::SecretDetection::GRPC::Client.new(
              sds_host,
              secure: sds_auth_token.present?,
              logger: secret_detection_logger
            )
          rescue StandardError => e
            ::Gitlab::ErrorTracking.track_exception(e)
            @sds_client = nil
          end
        end

        # Build an array of gRPC Exclusion messages from our exclusion hashes.
        def build_exclusions(exclusions: {})
          exclusions.flat_map do |_, exclusions_for_type|
            exclusions_for_type.map do |exclusion|
              type = ::Gitlab::Checks::SecretPushProtection::ExclusionsManager::EXCLUSION_TYPE_MAP.fetch(
                exclusion.type.to_sym,
                ::Gitlab::Checks::SecretPushProtection::ExclusionsManager::EXCLUSION_TYPE_MAP[:unknown]
              )

              ::Gitlab::SecretDetection::GRPC::Exclusion.new(
                exclusion_type: type,
                value: exclusion.value
              )
            end
          end
        end

        # Puts the entire gRPC request object together
        def build_sds_request(payloads, exclusions: {}, tags: [])
          ::Gitlab::SecretDetection::GRPC::ScanRequest.new(
            payloads: payloads,
            exclusions: build_exclusions(exclusions: exclusions),
            tags: tags
          )
        end

        def secret_detection_logger
          @secret_detection_logger ||= ::Gitlab::SecretDetectionLogger.build
        end
      end
    end
  end
end
