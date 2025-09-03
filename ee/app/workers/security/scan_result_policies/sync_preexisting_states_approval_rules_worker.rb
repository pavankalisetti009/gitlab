# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class SyncPreexistingStatesApprovalRulesWorker
      include ApplicationWorker
      include ::Security::SecurityOrchestrationPolicies::PolicySyncState::Callbacks

      idempotent!
      data_consistency :always

      queue_namespace :security_scans
      feature_category :security_policy_management

      def perform(merge_request_id)
        merge_request = MergeRequest.find_by_id(merge_request_id)
        return unless merge_request

        Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesService.new(merge_request).execute
        Security::ScanResultPolicies::UpdateLicenseApprovalsService.new(merge_request, nil, true).execute

        finish_merge_request_worker_policy_sync(merge_request_id)
      end
    end
  end
end
