# frozen_string_literal: true

module Security
  class SyncProjectPolicyWorker
    include ApplicationWorker

    data_consistency :sticky
    idempotent!
    deduplicate :until_executed

    concurrency_limit -> { 200 }

    feature_category :security_policy_management

    def perform(project_id, security_policy_id, policy_changes)
      project = Project.find_by_id(project_id)
      security_policy = Security::Policy.find_by_id(security_policy_id)

      return unless project && security_policy

      Security::SecurityOrchestrationPolicies::SyncProjectService.new(
        security_policy: security_policy,
        project: project,
        policy_changes: policy_changes.deep_symbolize_keys
      ).execute
    end
  end
end
