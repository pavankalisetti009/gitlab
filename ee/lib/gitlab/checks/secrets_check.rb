# frozen_string_literal: true

module Gitlab
  module Checks
    class SecretsCheck < ::Gitlab::Checks::BaseBulkChecker
      include ::Gitlab::InternalEventsTracking
      include ::Gitlab::Utils::StrongMemoize
      include ::Gitlab::Loggable

      ERROR_MESSAGES = {
        scan_initialization_error: 'Secret detection scan failed to initialize. %{error_msg}'
      }.freeze

      LOG_MESSAGES = {
        secrets_check: 'Detecting secrets...',
        invalid_encoding: "Could not convert data to UTF-8 from %{encoding}",
        sds_disabled: "SDS is disabled: FF: %{sds_ff_enabled}, SaaS: %{saas_feature_enabled}, " \
                      "Non-Dedicated: %{is_not_dedicated}"
      }.freeze

      # rubocop:disable Metrics/AbcSize -- This will be refactored in this epic (https://gitlab.com/groups/gitlab-org/-/epics/16376)
      def validate!
        eligibility_checker = Gitlab::Checks::SecretPushProtection::EligibilityChecker.new(
          project: project,
          changes_access: changes_access,
          audit_logger: audit_logger
        )

        return unless eligibility_checker.should_scan?

        return unless use_diff_scan?

        if use_secret_detection_service?
          sds_host = ::Gitlab::CurrentSettings.current_application_settings.secret_detection_service_url
          @sds_auth_token = ::Gitlab::CurrentSettings.current_application_settings.secret_detection_service_auth_token

          unless sds_host.blank?
            begin
              @sds_client =
                ::Gitlab::SecretDetection::GRPC::Client.new(
                  sds_host,
                  secure: !sds_auth_token.blank?,
                  logger: secret_detection_logger
                )
            rescue StandardError => e # Currently we want to catch and simply log errors
              @sds_client = nil
              ::Gitlab::ErrorTracking.track_exception(e)
            end
          end
        end

        thread = nil

        logger.log_timed(LOG_MESSAGES[:secrets_check]) do
          # Ensure consistency between different payload types (e.g., git diffs and full files) for scanning.
          processor = Gitlab::Checks::SecretPushProtection::PayloadProcessor.new(
            project: project,
            changes_access: changes_access
          )
          payloads = processor.standardize_payloads

          if use_secret_detection_service?
            thread = Thread.new do
              # This is to help identify the thread in case of a crash
              Thread.current.name = "secrets_check"

              # All the code run in the thread handles exceptions so we can leave these off
              Thread.current.abort_on_exception = false
              Thread.current.report_on_exception = false

              send_request_to_sds(payloads, exclusions: exclusions_manager.active_exclusions)
            end
          end

          # Pass payloads to gem for scanning.
          response = ::Gitlab::SecretDetection::Core::Scanner
            .new(rules: ruleset, logger: secret_detection_logger)
            .secrets_scan(
              payloads,
              timeout: logger.time_left,
              exclusions: exclusions_manager.active_exclusions
            )

          # Log audit events for exlusions that were applied.
          audit_logger.log_applied_exclusions_audit_events(response.applied_exclusions)

          # Handle the response depending on the status returned.
          response_handler = Gitlab::Checks::SecretPushProtection::ResponseHandler.new(
            project: project,
            changes_access: changes_access
          )

          response = response_handler.format_response(response)

          # Wait for the thread to complete up until we time out, returns `nil` on timeout
          thread&.join(logger.time_left)

          response
        # TODO: Perhaps have a separate message for each and better logging?
        rescue ::Gitlab::SecretDetection::Core::Ruleset::RulesetParseError,
          ::Gitlab::SecretDetection::Core::Ruleset::RulesetCompilationError => e

          message = format(ERROR_MESSAGES[:scan_initialization_error], { error_msg: e.message })
          secret_detection_logger.error(build_structured_payload(message:))
        ensure
          # clean up the thread
          thread&.exit
        end
      end
      # rubocop:enable Metrics/AbcSize

      private

      attr_reader :sds_client, :sds_auth_token

      ##############################
      # Helpers

      def ruleset
        ::Gitlab::SecretDetection::Core::Ruleset.new(
          logger: secret_detection_logger
        ).rules
      end

      strong_memoize_attr :ruleset

      ##############################
      # Project Eligibility Checks

      def use_secret_detection_service?
        return @should_use_sds unless @should_use_sds.nil?

        sds_ff_enabled = Feature.enabled?(:use_secret_detection_service, project)
        saas_feature_enabled = ::Gitlab::Saas.feature_available?(:secret_detection_service)
        is_not_dedicated = !::Gitlab::CurrentSettings.gitlab_dedicated_instance

        @should_use_sds = sds_ff_enabled && saas_feature_enabled && is_not_dedicated

        unless @should_use_sds
          msg = format(LOG_MESSAGES[:sds_disabled], { sds_ff_enabled:, saas_feature_enabled:, is_not_dedicated: })
          secret_detection_logger.info(build_structured_payload(message: msg))
        end

        @should_use_sds
      end

      ###############
      # Scan Checks

      def http_or_ssh_protocol?
        %w[http ssh].include?(changes_access.protocol)
      end

      def use_diff_scan?
        http_or_ssh_protocol? || secrets_check_enabled_for_web_requests?
      end

      def secrets_check_enabled_for_web_requests?
        return false if changes_access.gitaly_context.nil?

        changes_access.gitaly_context['enable_secrets_check'] == true
      end

      ############################
      # Audits and Event Logging

      def audit_logger
        @audit_logger ||= Gitlab::Checks::SecretPushProtection::AuditLogger.new(
          project: project,
          changes_access: changes_access
        )
      end

      def secret_detection_logger
        @secret_detection_logger ||= ::Gitlab::SecretDetectionLogger.build
      end

      #######################
      # Format Scan Results

      def revisions
        @revisions ||= changes_access
                        .changes
                        .pluck(:newrev) # rubocop:disable CodeReuse/ActiveRecord -- Array#pluck
                        .reject { |revision| ::Gitlab::Git.blank_ref?(revision) }
                        .compact
      end

      ##############
      # Exclusions

      def exclusions_manager
        @exclusions_manager ||= ::Gitlab::Checks::SecretPushProtection::ExclusionsManager.new(
          project: project,
          audit_logger: audit_logger
        )
      end

      ##############
      # GRPC Client Helpers

      def send_request_to_sds(payloads, exclusions: {})
        return if sds_client.nil?

        request = build_sds_request(payloads, exclusions: exclusions)

        # ignore the response for now
        _ = sds_client.run_scan(request: request, auth_token: sds_auth_token)
      rescue StandardError => e # Currently we want to catch and simply log errors
        ::Gitlab::ErrorTracking.track_exception(e)
      end

      # Build the list of gRPC Exclusion objects
      def build_exclusions(exclusions: {})
        exclusion_ary = []

        # exclusions are a hash of {string, array} pairs where the keys
        # are exclusion types like raw_value or path
        exclusions.each_key do |key|
          exclusions[key].inject(exclusion_ary) do |array, exclusion|
            type = ::Gitlab::Checks::SecretPushProtection::ExclusionsManager::EXCLUSION_TYPE_MAP.fetch(
              exclusion.type.to_sym,
              ::Gitlab::Checks::SecretPushProtection::ExclusionsManager::EXCLUSION_TYPE_MAP[:unknown])

            array << ::Gitlab::SecretDetection::GRPC::Exclusion.new(
              exclusion_type: type,
              value: exclusion.value
            )
          end
        end

        exclusion_ary
      end

      # Puts the entire gRPC request object together
      def build_sds_request(payloads, exclusions: {}, tags: [])
        exclusion_ary = build_exclusions(exclusions:)

        ::Gitlab::SecretDetection::GRPC::ScanRequest.new(
          payloads: payloads,
          exclusions: exclusion_ary,
          tags: tags
        )
      end
    end
  end
end
