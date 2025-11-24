# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class CreateProjectWarnModeAuditEventsWorker
      include ApplicationWorker

      data_consistency :sticky
      deduplicate :until_executing
      concurrency_limit -> { 200 }
      feature_category :security_policy_management
      idempotent!

      def perform(project_id, policy_id)
        # no-op
      end
    end
  end
end
