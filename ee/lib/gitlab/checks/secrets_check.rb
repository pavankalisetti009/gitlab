# frozen_string_literal: true

module Gitlab
  module Checks
    class SecretsCheck < ::Gitlab::Checks::BaseBulkChecker
      include Gitlab::InternalEventsTracking

      ERROR_MESSAGES = {
        failed_to_scan_regex_error: "\n    - Failed to scan blob(id: %{blob_id}) due to regex error.",
        blob_timed_out_error: "\n    - Scanning blob(id: %{blob_id}) timed out.",
        scan_timeout_error: 'Secret detection scan timed out.',
        scan_initialization_error: 'Secret detection scan failed to initialize.',
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
        finding_message: "\n\nSecret leaked in blob: %{blob_id}" \
                         "\n  -- line:%{line_number} | %{description}",
        found_secrets_footer: "\n--------------------------------------------------\n\n"
      }.freeze

      PAYLOAD_BYTES_LIMIT = 1.megabyte # https://handbook.gitlab.com/handbook/engineering/architecture/design-documents/secret_detection/#target-types
      SPECIAL_COMMIT_FLAG = /\[skip secret push protection\]/i
      DOCUMENTATION_PATH = 'user/application_security/secret_detection/secret_push_protection/index.html'
      DOCUMENTATION_PATH_ANCHOR = 'resolve-a-blocked-push'
      EXCLUSION_TYPE_MAP = {
        path: ::Gitlab::SecretDetection::GRPC::ScanRequest::ExclusionType::EXCLUSION_TYPE_RULE,
        raw_value: ::Gitlab::SecretDetection::GRPC::ScanRequest::ExclusionType::EXCLUSION_TYPE_RAW_VALUE
      }.freeze
      UNKNOWN_EXCLUSION_TYPE = ::Gitlab::SecretDetection::GRPC::ScanRequest::ExclusionType::EXCLUSION_TYPE_UNSPECIFIED
      HUNK_HEADER_REGEX = /\A@@ -\d+(,\d+)? \+(\d+)(,\d+)? @@\Z/

      # Maximum depth any path exclusion can have.
      MAX_PATH_EXCLUSIONS_DEPTH = 20

      # rubocop:disable  Metrics/PerceivedComplexity -- Temporary increase in complexity
      # rubocop:disable  Metrics/CyclomaticComplexity -- Temporary increase in complexity
      def validate!
        # Return early and do not perform the check:
        #   1. unless license is ultimate
        #   2. unless application setting is enabled
        #   3. unless instance is a Gitlab Dedicated instance or feature flag is enabled for this project
        #   4. unless project setting is enabled
        #   4. if it is a delete branch/tag operation, as it would require scanning the entire revision history
        #   5. if options are passed for us to skip the check

        return unless project.licensed_feature_available?(:pre_receive_secret_detection)

        return unless run_pre_receive_secret_detection?

        return if includes_full_revision_history?

        # Skip if any commit has the special bypass flag `[skip secret push protection]`
        if skip_secret_detection_commit_message?
          log_audit_event(_("commit message")) # Keeping this a string and not constant so I18N picks it up
          track_spp_skipped("commit message")
          return
        end

        if skip_secret_detection_push_option?
          log_audit_event(_("push option")) # Keeping this a string and not constant so I18N picks it up
          track_spp_skipped("push option")
          return
        end

        if Feature.enabled?(:use_secret_detection_service, project) &&
            ::Gitlab::Saas.feature_available?(:secret_detection_service) &&
            !::Gitlab::CurrentSettings.gitlab_dedicated_instance
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
              secret_detection_logger.error(e.message)
            end
          end
        end

        logger.log_timed(LOG_MESSAGES[:secrets_check]) do
          # Ensure consistency between different payload types (e.g., git diffs and full files) for scanning.
          payloads = standardize_payloads

          send_request_to_sds(payloads, exclusions: active_exclusions)

          # Pass payloads to gem for scanning.
          response = ::Gitlab::SecretDetection::Scan
            .new(logger: secret_detection_logger)
            .secrets_scan(payloads, timeout: logger.time_left, exclusions: active_exclusions)

          # Log audit events for exlusions that were applied.
          log_applied_exclusions_audit_events(response.applied_exclusions)

          # Handle the response depending on the status returned.
          format_response(response)

        # TODO: Perhaps have a separate message for each and better logging?
        rescue ::Gitlab::SecretDetection::Scan::RulesetParseError,
          ::Gitlab::SecretDetection::Scan::RulesetCompilationError => _
          secret_detection_logger.error(message: ERROR_MESSAGES[:scan_initialization_error])
        end
      end
      # rubocop:enable  Metrics/PerceivedComplexity
      # rubocop:enable  Metrics/CyclomaticComplexity

      private

      attr_reader :sds_client, :sds_auth_token

      ##############################
      # Project Eligibility Checks

      def run_pre_receive_secret_detection?
        Gitlab::CurrentSettings.current_application_settings.pre_receive_secret_detection_enabled &&
          (enabled_for_non_dedicated_project? || enabled_for_dedicated_project?)
      end

      def enabled_for_non_dedicated_project?
        ::Feature.enabled?(:pre_receive_secret_detection_push_check, project) &&
          project.security_setting&.pre_receive_secret_detection_enabled
      end

      def enabled_for_dedicated_project?
        ::Gitlab::CurrentSettings.gitlab_dedicated_instance &&
          project.security_setting&.pre_receive_secret_detection_enabled
      end

      ###############
      # Scan Checks

      def http_or_ssh_protocol?
        %w[http ssh].include?(changes_access.protocol)
      end

      def use_diff_scan?
        Feature.enabled?(:spp_scan_diffs, project) && http_or_ssh_protocol?
      end

      def includes_full_revision_history?
        Gitlab::Git.blank_ref?(changes_access.changes.first[:newrev])
      end

      def skip_secret_detection_commit_message?
        changes_access.commits.any? { |commit| commit.safe_message =~ SPECIAL_COMMIT_FLAG }
      end

      def skip_secret_detection_push_option?
        changes_access.push_options&.get(:secret_push_protection, :skip_all)
      end

      ############################
      # Audits and Event Logging

      def secret_detection_logger
        @secret_detection_logger ||= ::Gitlab::SecretDetectionLogger.build
      end

      def log_audit_event(skip_method)
        branch_name = changes_access.single_change_accesses.first.branch_name
        message = "#{_('Secret push protection skipped via')} #{skip_method} on branch #{branch_name}"

        audit_context = {
          name: 'skip_secret_push_protection',
          author: changes_access.user_access.user,
          target: project,
          scope: project,
          message: message
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      def log_applied_exclusions_audit_events(applied_exclusions)
        # Calling ::Gitlab::Audit::Auditor.audit directly in `gitlab-secret_detection` gem is not
        # feasible so instead of doing that, we loop through exclusions that have been applied during
        # scanning of either `rule` or `raw_value` type. For `path` exclusions, we create the audit events
        # when applied while formatting the response.
        applied_exclusions.each do |exclusion|
          log_exclusion_audit_event(exclusion)
        end
      end

      def log_exclusion_audit_event(exclusion)
        audit_context = {
          name: 'project_security_exclusion_applied',
          author: changes_access.user_access.user,
          target: exclusion,
          scope: project,
          message: "An exclusion of type (#{exclusion.type}) with value (#{exclusion.value}) was " \
                   "applied in Secret push protection"
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      def track_spp_skipped(skip_method)
        track_internal_event(
          'skip_secret_push_protection',
          user: changes_access.user_access.user,
          project: project,
          namespace: project.namespace,
          additional_properties: {
            label: skip_method
          }
        )
      end

      def track_secret_found(secret_type)
        track_internal_event(
          'detect_secret_type_on_push',
          user: changes_access.user_access.user,
          project: changes_access.project,
          namespace: changes_access.project.namespace,
          additional_properties: {
            label: secret_type
          }
        )
      end

      #######################
      # Load Payloads

      # The `standardize_payloads` method gets payloads containing either git diffs or entire file contents
      # and converts them into a standardized format. Each payload is processed to include its `id`, `data`,
      # and `offset` (used to calculate the line number that a secret is on).
      # This ensures consistency between different payload types (e.g., git diffs and full files) for scanning.
      # For a more thorough explanation of the diff parsing logic, see the comment above the `parse_diffs` method.

      def standardize_payloads
        if use_diff_scan?
          payloads = get_diffs

          payloads.flat_map do |payload|
            parse_diffs(payload)
          end
        else
          payloads = ::Gitlab::Checks::ChangedBlobs.new(
            project, revisions, bytes_limit: PAYLOAD_BYTES_LIMIT + 1
          ).execute(timeout: logger.time_left)

          # Filter out larger than PAYLOAD_BYTES_LIMIT blobs and binary blobs.
          payloads.reject! { |payload| payload.size > PAYLOAD_BYTES_LIMIT || payload.binary }

          payloads.map do |payload|
            {
              id: payload.id,
              data: payload.data,
              offset: 1
            }
          end
        end
      end

      def get_diffs
        diffs = []
        # Get new commits
        commits = project.repository.new_commits(revisions)

        # Get changed paths
        paths = project.repository.find_changed_paths(commits, merge_commit_diff_mode: :all_parents)

        # Reject diff blob objects from paths that are excluded
        # -- TODO: pass changed paths with diff blob objects and move this exclusion process into the gem.
        paths.reject! { |changed_path| matches_excluded_path?(changed_path.path) }

        # Make multiple DiffBlobsRequests with smaller batch sizes to prevent timeout when generating diffs
        paths.each_slice(50) do |paths_slice|
          blob_pair_ids = paths_slice.map do |path|
            Gitaly::DiffBlobsRequest::BlobPair.new(
              left_blob: path.old_blob_id,
              right_blob: path.new_blob_id
            )
          end

          diff_slice = project.repository.diff_blobs(blob_pair_ids, patch_bytes_limit: PAYLOAD_BYTES_LIMIT).to_a

          # Filter out diffs above 1 Megabyte and binary diffs
          filtered_diffs = diff_slice.reject { |diff| diff.over_patch_bytes_limit || diff.binary }

          diffs.concat(filtered_diffs)
        rescue GRPC::InvalidArgument => e
          secret_detection_logger.error(message: e.message)
        end
        diffs
      end

      # The parse_diffs method processes a diff patch to extract and group all added lines
      #   based on their position in the file.
      #
      # If the line starts with "@@", it is the hunk header, used to calculate the line offset.
      # If the line starts with "+", it is newly added in this commit,
      #   and we append the line content to a buffer and track the current line offset.
      #   If consecutive lines are added, they are grouped together in the same string with a shared offset value.
      # If the line starts with " ", it is a context line,
      #   just increment the offset counter to maintain accurate line numbers.
      # Lines starting with "-" (removed lines) and "\\" (end of diff) are ignored.
      #
      # Once the entire diff is parsed, the method returns an array of hashes containing:
      # - `id`: The id of the blob that the diff corresponds to (`diff.right_blob_id`).
      # - `data`: A string representing the concatenated added lines.
      # - `offset`: An integer indicating the line number in the file where this group of added lines starts.
      #
      # So for this example diff:
      #
      # @@ -0,0 +1,2 @@
      # +new line
      # +another added line in the same section
      # @@ -7,1 +8,2 @@
      #  unchanged line here
      # +another new line
      #
      # We would process it into:
      #
      # [{
      #    id: "123abc",
      #    data: "new line\nanother added line in the same section\n",
      #    offset: 1
      #  },
      #  {
      #    id: "123abc",
      #    data: "another new line\n",
      #    offset: 8
      #  }]

      def parse_diffs(diff)
        diff_parsed_lines = []
        current_line_number = 0
        added_content = ''
        offset = nil

        diff.patch.each_line do |line|
          # Parse hunk header for start line
          if line.start_with?("@@")
            hunk_info = line.match(HUNK_HEADER_REGEX)
            start_line = hunk_info[2].to_i
            current_line_number = start_line - 1

            # Push previous payload if not empty
            unless added_content.empty?
              diff_parsed_lines << { id: diff.right_blob_id, data: added_content.delete_suffix("\n"), offset: offset }
              added_content = ''
              offset = nil
            end
          # Line added in this commit
          elsif line.start_with?('+')
            added_content += line[1..] # Add the line content without '+'
            current_line_number += 1
            offset ||= current_line_number

          # Context line
          elsif line.start_with?(' ')
            unless added_content.empty?
              diff_parsed_lines << { id: diff.right_blob_id, data: added_content.delete_suffix("\n"), offset: offset }
              added_content = ''
              offset = nil
            end

            current_line_number += 1
          elsif line.start_with?('-', '\\')
            # Line removed in this commit or no newline marker, do not increment line number
            next
          end
        end

        # Push the final payload if not empty
        unless added_content.empty?
          diff_parsed_lines << {
            id: diff.right_blob_id, data: added_content.delete_suffix("\n"), offset: offset
          }
        end

        diff_parsed_lines
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
          ::Gitlab::SecretDetection::Status::FOUND,
          ::Gitlab::SecretDetection::Status::FOUND_WITH_ERRORS
        ].include?(response.status)
          results = transform_findings(response)

          # If there is no findings in `response.results`, that means all findings
          # were excluded in `transform_findings`, so we set status to no secrets found.
          response.status = ::Gitlab::SecretDetection::Status::NOT_FOUND if response.results.empty?
        end

        case response.status
        when ::Gitlab::SecretDetection::Status::NOT_FOUND
          # No secrets found, we log and skip the check.
          secret_detection_logger.info(message: LOG_MESSAGES[:secrets_not_found])
        when ::Gitlab::SecretDetection::Status::FOUND
          # One or more secrets found, generate message with findings and fail check.
          message = build_secrets_found_message(results)

          secret_detection_logger.info(message: LOG_MESSAGES[:found_secrets])

          raise ::Gitlab::GitAccess::ForbiddenError, message
        when ::Gitlab::SecretDetection::Status::FOUND_WITH_ERRORS
          # One or more secrets found, but with scan errors, so we
          # generate a message with findings and errors, and fail the check.
          message = build_secrets_found_message(results, with_errors: true)

          secret_detection_logger.info(message: LOG_MESSAGES[:found_secrets_with_errors])

          raise ::Gitlab::GitAccess::ForbiddenError, message
        when ::Gitlab::SecretDetection::Status::SCAN_TIMEOUT
          # Entire scan timed out, we log and skip the check for now.
          secret_detection_logger.error(message: ERROR_MESSAGES[:scan_timeout_error])
        when ::Gitlab::SecretDetection::Status::INPUT_ERROR
          # Scan failed due to invalid input. We skip the check because an input error
          # could be due to not having `diffs` being empty (i.e. no new diffs to scan).
          secret_detection_logger.error(message: ERROR_MESSAGES[:invalid_input_error])
        else
          # Invalid status returned by the scanning service/gem, we don't
          # know how to handle that, so nothing happens and we skip the check.
          secret_detection_logger.error(message: ERROR_MESSAGES[:invalid_scan_status_code_error])
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
              DOCUMENTATION_PATH,
              anchor: DOCUMENTATION_PATH_ANCHOR
            )
          }
        )

        message += LOG_MESSAGES[:skip_secret_detection]
        message += LOG_MESSAGES[:found_secrets_footer]
        message
      end

      def build_finding_message(finding, type)
        case finding.status
        when ::Gitlab::SecretDetection::Status::FOUND
          track_secret_found(finding.description)

          case type
          when :commit
            build_commit_finding_message(finding)
          when :blob
            build_blob_finding_message(finding)
          end
        when ::Gitlab::SecretDetection::Status::SCAN_ERROR
          format(ERROR_MESSAGES[:failed_to_scan_regex_error], finding.to_h)
        when ::Gitlab::SecretDetection::Status::PAYLOAD_TIMEOUT
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
        findings_by_blobs = response.results.group_by(&:blob_id)

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
              message: format(ERROR_MESSAGES[:too_many_tree_entries_error], { sha: revision })
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
            if matches_excluded_path?(entry.path)
              response.results.delete_if { |finding| finding.blob_id == entry.id }

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
        findings_by_blobs.delete_if { |blob_id, _| blobs_found_with_tree_entries.include?(blob_id) }

        # Return the findings as a hash sorted by commits and blobs (minus ones already found).
        {
          commits: findings_by_commits,
          blobs: findings_by_blobs
        }
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      ##############
      # Exclusions

      def active_exclusions
        @active_exclusions ||= project
          .security_exclusions
          .by_scanner(:secret_push_protection)
          .active
          .select(:type, :value)
          .group_by { |exclusion| exclusion.type.to_sym }
      end

      def matches_excluded_path?(path)
        # Skip paths that are too deep.
        return false if path.count('/') > MAX_PATH_EXCLUSIONS_DEPTH

        # Check only the maximum amount of path exclusions allowed (i.e. 10 path exclusions).
        active_exclusions[:path]
          &.first(::Security::ProjectSecurityExclusion::MAX_PATH_EXCLUSIONS_PER_PROJECT)
          &.any? do |exclusion|
          matches = File.fnmatch?(
            exclusion.value,
            path,
            File::FNM_DOTMATCH | File::FNM_EXTGLOB | File::FNM_PATHNAME
          )

          log_exclusion_audit_event(exclusion) if matches

          matches
        end
      end

      ##############
      # GRPC Client Helpers

      def send_request_to_sds(payloads, exclusions: {})
        return if sds_client.nil?

        request = build_sds_request(payloads, exclusions: exclusions)

        # ignore the response for now
        _ = sds_client.run_scan(request: request, auth_token: sds_auth_token)
      rescue StandardError => e # Currently we want to catch and simply log errors
        secret_detection_logger.error(message: e.message)
      end

      def build_sds_request(data, exclusions: {}, tags: [])
        payloads = data.inject([]) do |payloads, datum|
          payloads << ::Gitlab::SecretDetection::GRPC::ScanRequest::Payload.new(
            id: datum[:id],
            data: datum[:data]
          )
        end

        exclusion_ary = []

        # exclusions are a hash of {string, array} pairs where the keys
        # are exclusion types like raw_value or path
        exclusions.each_key do |key|
          exclusions[key].inject(exclusion_ary) do |array, exclusion|
            type = EXCLUSION_TYPE_MAP[exclusion.type.to_sym] || UNKNOWN_EXCLUSION_TYPE

            array << ::Gitlab::SecretDetection::GRPC::ScanRequest::Exclusion.new(
              exclusion_type: type,
              value: exclusion.value
            )
          end
        end

        Gitlab::SecretDetection::GRPC::ScanRequest.new(
          payloads: payloads,
          exclusions: exclusion_ary,
          tags: tags
        )
      end
    end
  end
end
