# frozen_string_literal: true

module MergeRequests
  class ResetApprovalsService < ::MergeRequests::BaseService
    include Gitlab::Utils::StrongMemoize

    def execute(ref, newrev, skip_reset_checks: false)
      reset_approvals_for_merge_requests(ref, newrev, skip_reset_checks)

      duration_statistics if log_reset_approvals_duration_enabled?
    end

    private

    def reset_approvals_for_merge_requests(ref, newrev, skip_reset_checks = false)
      branch_name = ::Gitlab::Git.ref_name(ref)

      merge_requests = merge_requests_for_approval_reset(branch_name)

      merge_requests.each do |merge_request|
        mr_patch_id_sha = merge_request.current_patch_id_sha

        if skip_reset_checks
          # Delete approvals immediately, with no additional checks or side-effects
          #
          delete_approvals(merge_request, patch_id_sha: mr_patch_id_sha, cause: :new_push)
        else
          reset_approvals(merge_request, newrev, patch_id_sha: mr_patch_id_sha)
        end

        # Note: When we remove the 10 second delay in
        # ee/app/services/ee/merge_requests/refresh_service.rb :51
        # We should be able to remove this
        merge_request.approval_state.expire_unapproved_key!
        trigger_merge_request_merge_status_updated(merge_request)
        AutoMergeProcessWorker.perform_async(merge_request.id) if merge_request.auto_merge_enabled?
      end
    end

    def reset_approvals(merge_request, newrev = nil, patch_id_sha: nil, cause: :new_push)
      return unless reset_approvals?(merge_request, newrev)

      if delete_approvals?(merge_request)
        delete_approvals(merge_request, patch_id_sha: patch_id_sha, cause: cause)
      elsif merge_request.target_project.project_setting.selective_code_owner_removals
        measure_duration_accumulate(:delete_code_owner_approvals_total) do
          delete_code_owner_approvals(merge_request, patch_id_sha: patch_id_sha, cause: cause)
        end
      end
    end

    def delete_code_owner_approvals(merge_request, patch_id_sha: nil, cause: nil)
      return if merge_request.approvals.empty?

      code_owner_rules = measure_duration_accumulate(:find_approved_code_owner_rules_total) do
        approved_code_owner_rules(merge_request)
      end
      return if code_owner_rules.empty?

      # Only do expensive approver ID extraction if we have code owner rules to check
      approver_ids = measure_duration_accumulate(:code_owner_approver_ids_to_delete_total) do
        code_owner_approver_ids_to_delete(merge_request, code_owner_rules, patch_id_sha)
      end
      return if approver_ids.empty?

      measure_duration_accumulate(:perform_code_owner_approval_deletion_total) do
        perform_code_owner_approval_deletion(merge_request, approver_ids, cause)
      end
    end

    def approved_code_owner_rules(merge_request)
      merge_request.wrapped_approval_rules.select { |rule| rule.code_owner? && rule.approved_approvers.any? }
    end

    def code_owner_approver_ids_to_delete(merge_request, code_owner_rules, patch_id_sha)
      previous_diff_head_sha = measure_duration_accumulate(:code_owner_approver_ids_previous_diff_sha) do
        merge_request.previous_diff&.head_commit_sha
      end

      rule_names = measure_duration_accumulate(:code_owner_approver_ids_entries_since_commit) do
        ::Gitlab::CodeOwners.entries_since_merge_request_commit(merge_request,
          sha: previous_diff_head_sha).map(&:pattern)
      end
      return [] if rule_names.empty?

      match_ids = measure_duration_accumulate(:code_owner_approver_ids_match_rules) do
        code_owner_rules.flat_map do |rule|
          next unless rule_names.include?(rule.name)

          rule.approved_approvers.map(&:id)
        end.compact
      end
      return [] if match_ids.empty?

      measure_duration_accumulate(:code_owner_approver_ids_filter_approvals) do
        filtered_approvals = merge_request.approvals.where(user_id: match_ids) # rubocop:disable CodeReuse/ActiveRecord
        filtered_approvals = filter_approvals(filtered_approvals, patch_id_sha) if patch_id_sha.present?
        filtered_approvals.map(&:user_id)
      end
    end

    def perform_code_owner_approval_deletion(merge_request, approver_ids, cause)
      merge_request.log_approval_deletion_on_merged_or_locked_mr(
        source: 'MergeRequests::ResetApprovalsService#perform_code_owner_approval_deletion',
        current_user: current_user,
        cause: cause
      )

      # Check if merge request is approved BEFORE deleting any approvals
      # We need to clear the approval state cache to get the current state
      was_approved = measure_duration_accumulate(:perform_deletion_check_approval_state) do
        merge_request.reset_approval_cache!
        merge_request.approval_state.all_approval_rules_approved?
      end

      measure_duration_accumulate(:perform_deletion_delete_all) do
        filtered_approvals = merge_request.approvals.where(user_id: approver_ids) # rubocop:disable CodeReuse/ActiveRecord
        filtered_approvals.delete_all
      end

      # In case there is still a temporary flag on the MR
      measure_duration_accumulate(:perform_deletion_expire_keys) do
        merge_request.approval_state.expire_unapproved_key!
      end

      measure_duration_accumulate(:perform_deletion_update_reviewer_state) do
        merge_request.batch_update_reviewer_state(approver_ids, 'unapproved')
      end

      measure_duration_accumulate(:perform_deletion_trigger_events) do
        trigger_merge_request_merge_status_updated(merge_request)
        trigger_merge_request_approval_state_updated(merge_request)
        publish_approvals_reset_event(merge_request, cause, approver_ids)
      end

      measure_duration_accumulate(:perform_deletion_webhooks) do
        trigger_code_owner_webhook_events(merge_request, was_approved, cause)
      end
    end

    def trigger_code_owner_webhook_events(merge_request, was_approved, cause)
      # Trigger webhook events for system-initiated approval resets
      return unless cause == :new_push

      # Check approval state AFTER deletion to determine correct webhook event
      # Clear memoization again to ensure we get the updated state after deletion
      merge_request.reset_approval_cache!
      is_currently_approved = merge_request.approval_state.all_approval_rules_approved?

      # Only send 'unapproved' if the MR transitioned from approved to not approved
      if was_approved && !is_currently_approved
        execute_hooks(merge_request, 'unapproved', system: true, system_action: 'code_owner_approvals_reset_on_push')
      else
        # Send 'unapproval' for individual approval removal that doesn't change overall approval state
        execute_hooks(merge_request, 'unapproval', system: true, system_action: 'code_owner_approvals_reset_on_push')
      end
    end

    def measure_duration_accumulate(operation_name)
      return yield unless log_reset_approvals_duration_enabled?

      start_time = current_monotonic_time
      result = yield
      duration = (current_monotonic_time - start_time)
      duration_statistics[:"#{operation_name}_duration_s"] ||= 0
      duration_statistics[:"#{operation_name}_duration_s"] += duration
      result
    end

    def duration_statistics
      @duration_statistics ||= {}
    end

    def log_reset_approvals_duration_enabled?
      Feature.enabled?(:log_merge_request_reset_approvals_duration, current_user)
    end
    strong_memoize_attr :log_reset_approvals_duration_enabled?

    def current_monotonic_time
      Gitlab::Metrics::System.monotonic_time
    end
  end
end
