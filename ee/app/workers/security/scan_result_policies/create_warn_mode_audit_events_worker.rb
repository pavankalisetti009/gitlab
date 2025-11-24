# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class CreateWarnModeAuditEventsWorker
      include ApplicationWorker

      data_consistency :sticky
      idempotent!
      feature_category :security_policy_management

      def perform(*)
        # no-op
      end
    end
  end
end
