# frozen_string_literal: true

module Gitlab
  module Checks
    class SecretsCheck < ::Gitlab::Checks::BaseBulkChecker
      include ::Gitlab::InternalEventsTracking
      include ::Gitlab::Utils::StrongMemoize
      include ::Gitlab::Loggable

      ERROR_MESSAGES = {
        failed_to_scan_regex_error: "\n    - Failed to scan blob(id: %{payload_id}) due to regex error.",
        blob_timed_out_error: "\n    - Scanning blob(id: %{payload_id}) timed out.",
        scan_timeout_error: 'Secret detection scan timed out.',
        scan_initialization_error: 'Secret detection scan failed to initialize. %{error_msg}',
        invalid_input_error: 'Secret detection scan failed due to invalid input.',
        invalid_scan_status_code_error: 'Invalid secret detection scan status, check passed.',
        too_many_tree_entries_error: 'Too many tree entries exist for commit(sha: %{sha}).'
      }.freeze

      LOG_MESSAGES = {
        secrets_check: 'Detecting secrets...',
        secrets_not_found: 'Secret detection scan completed with no findings.',
        skip_secret_detection: "\n\nTo skip secret push protection, add the following Git push option " \
                               "to your push command: `-o secret_push_protection.skip_all`",
        found_secrets: "\nPUSH BLOCKED: Secrets detected in code changes",
        found_secrets_post_message: "\n\nTo push your changes you must remove the identified secrets.",
        found_secrets_docs_link: "\nFor guidance, see %{path}",
        found_secrets_with_errors: 'Secret detection scan completed with one or more findings ' \
                                   'but some errors occured during the scan.',
        finding_message_occurrence_header: "\n\nSecret push protection " \
                                           "found the following secrets in commit: %{sha}",
        finding_message_occurrence_path: "\n-- %{path}:",
        finding_message_occurrence_line: "%{line_number} | %{description}",
        finding_message: "\n\nSecret leaked in blob: %{payload_id}" \
                         "\n  -- line:%{line_number} | %{description}",
        found_secrets_footer: "\n--------------------------------------------------\n\n",
        sds_disabled: "SDS is disabled: FF: %{sds_ff_enabled}, SaaS: %{saas_feature_enabled}, " \
                      "Non-Dedicated: %{is_not_dedicated}",
        invalid_log_level: "Unknown log level %{log_level} for message: %{message}"
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
          response = format_response(response)

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

      def commits
        @commit ||= changes_access.commits.map(&:valid_full_sha)
      end

      def revisions
        @revisions ||= changes_access
                        .changes
                        .pluck(:newrev) # rubocop:disable CodeReuse/ActiveRecord -- Array#pluck
                        .reject { |revision| ::Gitlab::Git.blank_ref?(revision) }
                        .compact
      end

      def format_response(response)
        # Try to retrieve file path and commit sha for the diffs found.
        if [
          ::Gitlab::SecretDetection::Core::Status::FOUND,
          ::Gitlab::SecretDetection::Core::Status::FOUND_WITH_ERRORS
        ].include?(response.status)
          results = transform_findings(response)

          # If there is no findings in `response.results`, that means all findings
          # were excluded in `transform_findings`, so we set status to no secrets found.
          response.status = ::Gitlab::SecretDetection::Status::NOT_FOUND if response.results.empty?
        end

        case response.status
        when ::Gitlab::SecretDetection::Core::Status::NOT_FOUND
          # No secrets found, we log and skip the check.
          secret_detection_logger.info(build_structured_payload(message: LOG_MESSAGES[:secrets_not_found]))
        when ::Gitlab::SecretDetection::Core::Status::FOUND
          # One or more secrets found, generate message with findings and fail check.
          message = build_secrets_found_message(results)

          secret_detection_logger.info(
            build_structured_payload(message: LOG_MESSAGES[:found_secrets])
          )

          raise ::Gitlab::GitAccess::ForbiddenError, message
        when ::Gitlab::SecretDetection::Core::Status::FOUND_WITH_ERRORS
          # One or more secrets found, but with scan errors, so we
          # generate a message with findings and errors, and fail the check.
          message = build_secrets_found_message(results, with_errors: true)

          secret_detection_logger.info(
            build_structured_payload(message: LOG_MESSAGES[:found_secrets_with_errors])
          )

          raise ::Gitlab::GitAccess::ForbiddenError, message
        when ::Gitlab::SecretDetection::Core::Status::SCAN_TIMEOUT
          # Entire scan timed out, we log and skip the check for now.
          secret_detection_logger.error(
            build_structured_payload(message: ERROR_MESSAGES[:scan_timeout_error])
          )
        when ::Gitlab::SecretDetection::Core::Status::INPUT_ERROR
          # Scan failed due to invalid input. We skip the check because of an input error
          # which could be due to not having anything to scan.
          secret_detection_logger.error(
            build_structured_payload(message: ERROR_MESSAGES[:invalid_input_error])
          )
        else
          # Invalid status returned by the scanning service/gem, we don't
          # know how to handle that, so nothing happens and we skip the check.
          secret_detection_logger.error(
            build_structured_payload(message: ERROR_MESSAGES[:invalid_scan_status_code_error])
          )
        end
      end

      def build_secrets_found_message(results, with_errors: false)
        message = with_errors ? LOG_MESSAGES[:found_secrets_with_errors] : LOG_MESSAGES[:found_secrets]

        results[:commits].each do |sha, paths|
          message += format(LOG_MESSAGES[:finding_message_occurrence_header], { sha: sha })

          paths.each do |path, findings|
            findings.each do |finding|
              message += format(LOG_MESSAGES[:finding_message_occurrence_path], { path: path })
              message += build_finding_message(finding, :commit)
            end
          end
        end

        results[:blobs].compact.each do |_, findings|
          findings.each do |finding|
            message += build_finding_message(finding, :blob)
          end
        end

        message += LOG_MESSAGES[:found_secrets_post_message]
        message += format(
          LOG_MESSAGES[:found_secrets_docs_link],
          {
            path: Rails.application.routes.url_helpers.help_page_url(
              'user/application_security/secret_detection/secret_push_protection/_index.md',
              anchor: 'resolve-a-blocked-push'
            )
          }
        )

        message += LOG_MESSAGES[:skip_secret_detection]
        message += LOG_MESSAGES[:found_secrets_footer]
        message
      end

      def build_finding_message(finding, type)
        case finding.status
        when ::Gitlab::SecretDetection::Core::Status::FOUND
          audit_logger.track_secret_found(finding.description)

          case type
          when :commit
            build_commit_finding_message(finding)
          when :blob
            build_blob_finding_message(finding)
          end
        when ::Gitlab::SecretDetection::Core::Status::SCAN_ERROR
          format(ERROR_MESSAGES[:failed_to_scan_regex_error], finding.to_h)
        when ::Gitlab::SecretDetection::Core::Status::PAYLOAD_TIMEOUT
          format(ERROR_MESSAGES[:blob_timed_out_error], finding.to_h)
        end
      end

      def build_commit_finding_message(finding)
        format(
          LOG_MESSAGES[:finding_message_occurrence_line],
          {
            line_number: finding.line_number,
            description: finding.description
          }
        )
      end

      def build_blob_finding_message(finding)
        format(LOG_MESSAGES[:finding_message], finding.to_h)
      end

      # rubocop:disable Metrics/CyclomaticComplexity -- Not easy to move complexity away into other methods, entire method will be refactored shortly.
      def transform_findings(response)
        # Let's group the findings by the blob id.
        findings_by_blobs = response.results.group_by(&:payload_id)

        # We create an empty hash for the structure we'll create later as we pull out tree entries.
        findings_by_commits = {}

        # Let's create a set to store ids of blobs found in tree entries.
        blobs_found_with_tree_entries = Set.new

        # Scanning had found secrets, let's try to look up their file path and commit id. This can be done
        # by using `GetTreeEntries()` RPC, and cross examining blobs with ones where secrets where found.
        commits.each do |revision|
          # We could try to handle pagination, but it is likely to timeout way earlier given the
          # huge default limit (100000) of entries, so we log an error if we get too many results.
          entries, cursor = ::Gitlab::Git::Tree.tree_entries(
            repository: project.repository,
            sha: revision,
            recursive: true,
            rescue_not_found: false
          )

          # TODO: Handle pagination in the upcoming iterations
          # We don't raise because we could still provide a hint to the user
          # about the detected secrets even without a commit sha/file path information.
          unless cursor.next_cursor.empty?
            secret_detection_logger.error(
              build_structured_payload(
                message: format(ERROR_MESSAGES[:too_many_tree_entries_error], { sha: revision })
              )
            )
          end

          # Let's grab the `commit_id` and the `path` for that entry, we use the blob id as key.
          entries.each do |entry|
            # Skip any entry that isn't a blob.
            next if entry.type != :blob

            # Skip if the blob doesn't have any findings.
            next unless findings_by_blobs[entry.id].present?

            # Skip a tree entry if it's excluded from scanning by the user based on its file
            # path. We unfortunately have to do this after scanning is done because we only get
            # file paths when calling `GetTreeEntries()` RPC and not earlier. When diff scanning
            # is available, we will likely be able move this check to the gem/secret detection service
            # since paths will be available pre-scanning.
            if exclusions_manager.matches_excluded_path?(entry.path)
              response.results.delete_if { |finding| finding.payload_id == entry.id }

              findings_by_blobs.delete(entry.id)

              next
            end

            new_entry = findings_by_blobs[entry.id].each_with_object({}) do |finding, hash|
              hash[entry.commit_id] ||= {}
              hash[entry.commit_id][entry.path] ||= []
              hash[entry.commit_id][entry.path] << finding
            end

            # Put findings with tree entries inside `findings_by_commits` hash.
            findings_by_commits.merge!(new_entry) do |_commit_sha, existing_findings, new_findings|
              existing_findings.merge!(new_findings)
            end

            # Mark as found with tree entry already.
            blobs_found_with_tree_entries << entry.id
          end
        end

        # Remove blobs that has already been found in a tree entry.
        findings_by_blobs.delete_if { |payload_id, _| blobs_found_with_tree_entries.include?(payload_id) }

        # Return the findings as a hash sorted by commits and blobs (minus ones already found).
        {
          commits: findings_by_commits,
          blobs: findings_by_blobs
        }
      end
      # rubocop:enable Metrics/CyclomaticComplexity

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
