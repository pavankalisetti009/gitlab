# frozen_string_literal: true

module Security
  module ScanResultPolicies
    # rubocop:disable Scalability/IdempotentWorker -- policy edits are indistinguishable
    class CreateProjectWarnModeAuditEventsWorker
      # rubocop:enable Scalability/IdempotentWorker
      include ApplicationWorker

      data_consistency :sticky
      deduplicate :until_executing

      feature_category :security_policy_management

      def perform(project_id, policy_id)
        project = Project.find_by_id(project_id) || return

        return if Feature.disabled?(:security_policy_approval_warn_mode, project)

        policy = Security::Policy.find_by_id(policy_id) || return

        Security::ScanResultPolicies::CreateProjectWarnModeAuditEventService
          .new(project, policy)
          .execute
      end
    end
  end
end
