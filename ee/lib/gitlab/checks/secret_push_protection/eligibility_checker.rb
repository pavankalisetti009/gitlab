# frozen_string_literal: true

module Gitlab
  module Checks
    module SecretPushProtection
      class EligibilityChecker
        SPECIAL_COMMIT_FLAG = /\[skip secret push protection\]/i

        def initialize(project:, changes_access:, audit_logger:)
          @project = project
          @changes_access = changes_access
          @audit_logger = audit_logger
        end

        def should_scan?
          # Return early and do not perform the check:
          #   1. unless license is ultimate
          #   2. unless application setting is enabled
          #   3. unless project setting is enabled
          #   4. if it is a delete branch/tag operation, as it would require scanning the entire revision history
          #   5. if options are passed for us to skip the check
          return false unless license_available?
          return false unless secret_push_protection_available?
          return false if includes_full_revision_history?

          if skip_secret_detection_commit_message?
            audit_logger.log_skip_secret_push_protection(_("commit message"))
            audit_logger.track_spp_skipped("commit message")
            return false
          end

          if skip_secret_detection_push_option?
            audit_logger.log_skip_secret_push_protection(_("push option"))
            audit_logger.track_spp_skipped("push option")
            return false
          end

          true
        end

        private

        attr_reader :project, :changes_access, :audit_logger

        def license_available?
          project.licensed_feature_available?(:secret_push_protection)
        end

        def secret_push_protection_available?
          Gitlab::CurrentSettings.current_application_settings.secret_push_protection_available &&
            project.security_setting&.secret_push_protection_enabled
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
      end
    end
  end
end
