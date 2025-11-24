# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class RecreateProjectWarnModeAuditEventsWorker
      include ApplicationWorker

      feature_category :security_policy_management
      data_consistency :sticky
      idempotent!

      def perform(*)
        # no-op
      end
    end
  end
end
