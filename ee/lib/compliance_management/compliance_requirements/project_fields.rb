# frozen_string_literal: true

module ComplianceManagement
  module ComplianceRequirements
    class ProjectFields
      FIELD_MAPPINGS = ComplianceManagement::ComplianceFramework::Controls::Registry.field_mappings.freeze

      SECURITY_SCANNERS = [
        :sast,
        :secret_detection,
        :dependency_scanning,
        :container_scanning,
        :license_compliance,
        :dast,
        :api_fuzzing,
        :fuzz_testing,
        :code_quality,
        :iac
      ].freeze

      class << self
        def map_field(project, field, context = {})
          method_name = FIELD_MAPPINGS[field]
          return unless method_name

          send(method_name, project, context) # rubocop:disable GitlabSecurity/PublicSend -- We control the `method` name
        end

        private

        def default_branch_protected?(project, _context = {})
          return false unless project.default_branch

          ProtectedBranch.protected?(project, project.default_branch)
        end

        def merge_request_prevent_author_approval?(project, context = {})
          settings_prevent_approval?("prevent_approval_by_author", context) ||
            !project.merge_requests_author_approval?
        end

        def merge_requests_disable_committers_approval?(project, context = {})
          settings_prevent_approval?("prevent_approval_by_commit_author", context) ||
            project.merge_requests_disable_committers_approval?
        end

        def project_visibility(project, _context = {})
          project.visibility
        end

        def minimum_approvals_required(project, _context = {})
          project.approval_rules.pick("SUM(approvals_required)") || 0
        end

        def auth_sso_enabled?(project, _context = {})
          return false unless project.group

          ::Groups::SsoHelper.saml_provider_enabled?(project.group)
        end

        def scanner_sast_running?(project, context = {})
          security_scanner_running?(:sast, project, context)
        end

        def scanner_secret_detection_running?(project, context = {})
          security_scanner_running?(:secret_detection, project, context)
        end

        def scanner_dep_scanning_running?(project, context = {})
          security_scanner_running?(:dependency_scanning, project, context)
        end

        def scanner_container_scanning_running?(project, context = {})
          security_scanner_running?(:container_scanning, project, context)
        end

        def scanner_license_compliance_running?(project, context = {})
          security_scanner_running?(:license_compliance, project, context)
        end

        def scanner_dast_running?(project, context = {})
          security_scanner_running?(:dast, project, context)
        end

        def scanner_api_security_running?(project, context = {})
          security_scanner_running?(:api_fuzzing, project, context)
        end

        def scanner_fuzz_testing_running?(project, context = {})
          security_scanner_running?(:fuzz_testing, project, context)
        end

        def scanner_code_quality_running?(project, context = {})
          security_scanner_running?(:code_quality, project, context)
        end

        def scanner_iac_running?(project, context = {})
          security_scanner_running?(:iac, project, context)
        end

        def security_scanner_running?(scanner, project, _context = {})
          pipeline = project.latest_successful_pipeline_for_default_branch

          return false if pipeline.nil?
          return false unless SECURITY_SCANNERS.include?(scanner)

          pipeline.job_artifacts.send(scanner).any? # rubocop: disable GitlabSecurity/PublicSend -- limited to supported scanners
        end

        def code_changes_requires_code_owners?(project, _context = {})
          ProtectedBranch.branch_requires_code_owner_approval?(project, nil)
        end

        def reset_approvals_on_push?(project, _context = {})
          project.reset_approvals_on_push
        end

        def status_checks_required?(project, _context = {})
          project.only_allow_merge_if_all_status_checks_passed
        end

        def require_branch_up_to_date?(project, _context = {})
          [:rebase_merge, :ff].include?(project.merge_method)
        end

        def resolve_discussions_required?(project, _context = {})
          project.only_allow_merge_if_all_discussions_are_resolved
        end

        def require_linear_history?(project, _context = {})
          [:rebase_merge, :merge].exclude?(project.merge_method)
        end

        def restrict_push_merge_access?(project, _context = {})
          !project.all_protected_branches.any?(&:allow_force_push)
        end

        def force_push_disabled?(project, _context = {})
          !ProtectedBranch.allow_force_push?(project, nil)
        end

        def terraform_enabled?(project, _context = {})
          project.terraform_states.exists?
        end

        def settings_prevent_approval?(setting_key, context = {})
          approval_settings = context[:approval_settings]
          return false if approval_settings.blank?

          approval_settings.any? do |settings|
            next false unless settings.is_a?(Hash)

            settings[setting_key] == true
          end
        end
      end
    end
  end
end
