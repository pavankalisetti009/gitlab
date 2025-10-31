# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class CreateWarnModeApprovalAuditEventsWorker
      include Gitlab::EventStore::Subscriber

      data_consistency :sticky
      idempotent!
      feature_category :security_policy_management

      def handle_event(event)
        merge_request_id, user_id = event.data.values_at(:merge_request_id, :current_user_id)

        merge_request = MergeRequest.find_by_id(merge_request_id) || return

        return unless merge_request.open? && Feature.enabled?(:security_policy_approval_warn_mode,
          merge_request.project)

        user = User.find_by_id(user_id) || return

        Security::ScanResultPolicies::CreateWarnModeApprovalAuditEventService
          .new(merge_request, user)
          .execute
      end
    end
  end
end
