# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class SyncMergeRequestsService < BaseMergeRequestsService
      extend ::Gitlab::Utils::Override

      def initialize(project:, security_policy:)
        super(project: project)

        @security_policy = security_policy
      end

      def execute
        measure(HISTOGRAM, callback: ->(duration) { log_duration(duration) }) do
          each_open_merge_request do |merge_request|
            sync_merge_request(merge_request)
          end
        end
      end

      private

      attr_reader :security_policy

      override :sync_policy_specific_approval_rules
      def sync_policy_specific_approval_rules(merge_request)
        merge_request.sync_project_approval_rules_for_approval_policy_rules(
          security_policy.approval_policy_rules.undeleted
        )
      end

      def policy_configuration
        security_policy.security_orchestration_policy_configuration
      end
    end
  end
end
