# frozen_string_literal: true

module Security
  class DeleteSecurityPolicyWorker
    include ApplicationWorker

    feature_category :security_policy_management
    data_consistency :sticky
    deduplicate :until_executed
    idempotent!

    def perform(security_policy_id)
      policy = Security::Policy.find_by_id(security_policy_id) || return

      Security::Policy.transaction do
        policy.delete_approval_policy_rules
        policy.delete_scan_execution_policy_rules

        policy.delete
      end
    end
  end
end
