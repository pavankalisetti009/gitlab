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
        invalid_encoding: "Could not convert data to UTF-8 from %{encoding}"
      }.freeze

      def validate!
        eligibility_checker = Gitlab::Checks::SecretPushProtection::EligibilityChecker.new(
          project: project,
          changes_access: changes_access,
          audit_logger: audit_logger
        )

        return unless eligibility_checker.should_scan?

        return unless use_diff_scan?

        sds_service = Gitlab::Checks::SecretPushProtection::SecretDetectionServiceClient.new(
          project: project
        )

        thread = nil

        logger.log_timed(LOG_MESSAGES[:secrets_check]) do
          # Ensure consistency between different payload types (e.g., git diffs and full files) for scanning.
          processor = Gitlab::Checks::SecretPushProtection::PayloadProcessor.new(
            project: project,
            changes_access: changes_access
          )
          payloads = processor.standardize_payloads

          thread = Thread.new do
            Thread.current.name = "secrets_check"
            Thread.current.abort_on_exception = false
            Thread.current.report_on_exception = false

            sds_service.send_request_to_sds(
              payloads,
              exclusions: exclusions_manager.active_exclusions
            )
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

      private

      ##############################
      # Helpers

      def ruleset
        ::Gitlab::SecretDetection::Core::Ruleset.new(
          logger: secret_detection_logger
        ).rules
      end

      strong_memoize_attr :ruleset

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
    end
  end
end
