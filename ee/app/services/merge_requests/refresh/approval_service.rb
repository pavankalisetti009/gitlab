# frozen_string_literal: true

module MergeRequests
  module Refresh
    class ApprovalService < ::MergeRequests::Refresh::BaseService
      extend ::Gitlab::Utils::Override

      attr_reader :push

      def execute(oldrev, newrev, ref)
        @push = Gitlab::Git::Push.new(@project, oldrev, newrev, ref)
        return true unless @push.branch_push?

        update_approvers_for_source_branch_merge_requests
        update_approvers_for_target_branch_merge_requests
        reset_approvals_for_merge_requests(push.ref, push.newrev)
        sync_any_merge_request_approval_rules
        sync_preexisting_states_approval_rules
        sync_unenforceable_approval_rules
      end

      private

      def update_approvers_for_source_branch_merge_requests
        merge_requests_for_source_branch.each do |merge_request|
          if project.licensed_feature_available?(:code_owners)
            ::MergeRequests::SyncCodeOwnerApprovalRules.new(merge_request).execute
          end

          ::MergeRequests::SyncReportApproverApprovalRules.new(merge_request, current_user).execute
        end
      end

      def reset_approvals_for_merge_requests(ref, newrev)
        # Add a flag that prevents unverified changes from getting through in the
        #   10 second window below
        merge_requests_for(push.branch_name, mr_states: [:opened]).each do |mr|
          mr.approval_state.temporarily_unapprove! if reset_approvals?(mr, newrev)
        end

        # We need to make sure the code owner approval rules have all been synced
        #   first, so we delay for 10s. We are trying to pin down and fix the race
        #   condition: https://gitlab.com/gitlab-org/gitlab/-/issues/373846
        #
        MergeRequestResetApprovalsWorker.perform_in(10.seconds, project.id, current_user.id, ref, newrev)
      end

      def update_approvers_for_target_branch_merge_requests
        return unless project.licensed_feature_available?(:code_owners) && branch_protected? && code_owners_updated?

        merge_requests_for_target_branch.each do |merge_request|
          ::MergeRequests::SyncCodeOwnerApprovalRules.new(merge_request).execute unless merge_request.on_train?
        end
      end

      def sync_any_merge_request_approval_rules
        return if project.scan_result_policy_reads.targeting_commits.none?

        merge_requests_for_source_branch.each do |merge_request|
          ::Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker.perform_async(merge_request.id)
        end
      end

      def sync_preexisting_states_approval_rules
        merge_requests_for_source_branch.each do |merge_request|
          if merge_request.approval_rules.by_report_types([:scan_finding, :license_scanning]).any?
            ::Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker.perform_async(merge_request.id)
          end
        end
      end

      def sync_unenforceable_approval_rules
        merge_requests_for_source_branch.each do |merge_request|
          unless merge_request.head_pipeline_id
            ::Security::UnenforceablePolicyRulesNotificationWorker.perform_async(merge_request.id)
          end
        end
      end

      def branch_protected?
        project.branch_requires_code_owner_approval?(push.branch_name)
      end

      def merge_requests_for_target_branch
        @target_merge_requests ||= project.merge_requests
          .with_state([:opened])
          .by_target_branch(push.branch_name)
          .including_merge_train
      end

      def code_owners_updated?
        return unless push.branch_updated?

        push.modified_paths.find { |path| ::Gitlab::CodeOwners::FILE_PATHS.include?(path) }
      end

      override :reset_approvals?
      def reset_approvals?(merge_request, newrev)
        !merge_request.merge_train_car && super
      end
    end
  end
end
