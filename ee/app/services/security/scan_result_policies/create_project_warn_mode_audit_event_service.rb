# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class CreateProjectWarnModeAuditEventService
      include Gitlab::Utils::StrongMemoize
      include Security::ScanResultPolicies::HumanizationHelpers

      AUDIT_EVENT = 'policy_warn_mode_approval_settings_overrides'

      def initialize(project, policy)
        @project = project
        @policy = policy
      end

      def execute
        return unless policy.warn_mode? && overrides.any? && policy.scope_applicable?(project)

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      def audit_context
        {
          name: AUDIT_EVENT,
          message: message,
          target: policy,
          scope: project,
          author: author
        }
      end

      private

      attr_reader :project, :policy

      def message
        "A merge request approval policy in warn mode sets more restrictive `approval_settings`: #{humanized_overrides}"
      end

      def author
        project.security_policy_bot || create_security_policy_bot!
      end

      def create_security_policy_bot!
        Security::Orchestration::CreateBotService.new(project, nil, skip_authorization: true).execute.user
      end

      def humanized_overrides
        overrides.map { |override| humanized_approval_setting(override.attribute) }.join(', ')
      end

      def overrides
        ::Security::ScanResultPolicies::ApprovalSettingsOverrides.new(
          project: project,
          warn_mode_policies: [policy],
          enforced_policies: enforced_policies
        ).all
      end
      strong_memoize_attr :overrides

      def enforced_policies
        project.security_policies.reject(&:warn_mode?)
      end
    end
  end
end
