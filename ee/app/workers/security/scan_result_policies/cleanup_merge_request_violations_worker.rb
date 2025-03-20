# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class CleanupMergeRequestViolationsWorker
      include Gitlab::EventStore::Subscriber
      include ::Security::ScanResultPolicies::PolicyLogger

      feature_category :security_policy_management
      data_consistency :sticky
      idempotent!

      def handle_event(event)
        merge_request = MergeRequest.find_by_id(event.data[:merge_request_id]) || return
        project = merge_request.project
        return if ::Feature.disabled?(:cleanup_stale_policy_violations, project)
        return unless project.licensed_feature_available?(:security_orchestration_policies)

        log_running_violations_after_merge(merge_request) if event.is_a?(::MergeRequests::MergedEvent)

        merge_request.scan_result_policy_violations.delete_all(:delete_all)
      end

      private

      def log_running_violations_after_merge(merge_request)
        running_violations = merge_request.running_scan_result_policy_violations
        return if running_violations.none?

        log_policy_evaluation('post_merge', 'Running scan result policy violations after merge',
          project: merge_request.project,
          merge_request_id: merge_request.id,
          merge_request_iid: merge_request.iid,
          head_pipeline_id: merge_request.diff_head_pipeline&.id,
          violation_ids: running_violations.map(&:id),
          scan_result_policy_ids: running_violations.filter_map(&:scan_result_policy_id),
          approval_policy_rule_ids: running_violations.filter_map(&:approval_policy_rule_id)
        )
      end
    end
  end
end
