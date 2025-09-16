# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class ProcessPipelineCompletionWorker
      include Gitlab::EventStore::Subscriber

      feature_category :security_policy_management
      data_consistency :sticky
      idempotent!
      deduplicate :until_executing, including_scheduled: true

      def handle_event(event)
        pipeline = Ci::Pipeline.find_by_id(event.data[:pipeline_id])
        return unless pipeline

        project = pipeline.project

        return unless project.licensed_feature_available?(:security_orchestration_policies)
        return unless project.can_store_security_reports?

        ::Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker.perform_async(pipeline.id)
      end
    end
  end
end
