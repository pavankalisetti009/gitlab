# frozen_string_literal: true

module MergeRequests
  class ResetApprovalsService < ::MergeRequests::BaseService
    include Gitlab::Utils::StrongMemoize

    def execute(ref, newrev, skip_reset_checks: false)
      measure_duration(:reset_approvals_for_merge_requests) do
        reset_approvals_for_merge_requests(ref, newrev, skip_reset_checks)
      end

      return unless log_reset_approvals_duration_enabled?

      log_hash_metadata_on_done(duration_statistics)
    end

    private

    # Note: Closed merge requests also need approvals reset.
    def reset_approvals_for_merge_requests(ref, newrev, skip_reset_checks = false)
      branch_name = ::Gitlab::Git.ref_name(ref)

      merge_requests = measure_duration(:find_merge_requests) do
        merge_requests_for(branch_name, mr_states: [:opened, :closed])
      end

      measure_duration(:process_merge_requests) do
        merge_requests.each do |merge_request|
          mr_patch_id_sha = measure_duration_accumulate(:current_patch_id_sha_total) do
            merge_request.current_patch_id_sha
          end

          if skip_reset_checks
            # Delete approvals immediately, with no additional checks or side-effects
            #
            measure_duration_accumulate(:delete_approvals_total) do
              delete_approvals(merge_request, patch_id_sha: mr_patch_id_sha, cause: :new_push)
            end
          else
            measure_duration_accumulate(:reset_approvals_total) do
              reset_approvals(merge_request, newrev, patch_id_sha: mr_patch_id_sha)
            end
          end

          # Note: When we remove the 10 second delay in
          # ee/app/services/ee/merge_requests/refresh_service.rb :51
          # We should be able to remove this
          AutoMergeProcessWorker.perform_async(merge_request.id) if merge_request.auto_merge_enabled?
        end
      end
    end

    def reset_approvals(merge_request, newrev = nil, patch_id_sha: nil, cause: :new_push)
      return unless reset_approvals?(merge_request, newrev)

      if delete_approvals?(merge_request)
        measure_duration_accumulate(:delete_all_approvals_total) do
          delete_approvals(merge_request, patch_id_sha: patch_id_sha, cause: cause)
        end
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
      approver_ids = measure_duration_accumulate(:extract_code_owner_approver_ids_total) do
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
      previous_diff_head_sha = merge_request.previous_diff&.head_commit_sha
      rule_names = ::Gitlab::CodeOwners.entries_since_merge_request_commit(merge_request,
        sha: previous_diff_head_sha).map(&:pattern)
      return [] if rule_names.empty?

      match_ids = code_owner_rules.flat_map do |rule|
        next unless rule_names.include?(rule.name)

        rule.approved_approvers.map(&:id)
      end.compact
      return [] if match_ids.empty?

      filtered_approvals = merge_request.approvals.where(user_id: match_ids) # rubocop:disable CodeReuse/ActiveRecord
      filtered_approvals = filter_approvals(filtered_approvals, patch_id_sha) if patch_id_sha.present?
      filtered_approvals.map(&:user_id)
    end

    def perform_code_owner_approval_deletion(merge_request, approver_ids, cause)
      # Check if merge request is approved BEFORE deleting any approvals
      # We need to clear the approval state cache to get the current state
      merge_request.reset_approval_cache!
      was_approved = merge_request.approval_state.all_approval_rules_approved?

      filtered_approvals = merge_request.approvals.where(user_id: approver_ids) # rubocop:disable CodeReuse/ActiveRecord
      filtered_approvals.delete_all

      # In case there is still a temporary flag on the MR
      merge_request.approval_state.expire_unapproved_key!

      merge_request.batch_update_reviewer_state(approver_ids, 'unapproved')

      trigger_merge_request_merge_status_updated(merge_request)
      trigger_merge_request_approval_state_updated(merge_request)
      publish_approvals_reset_event(merge_request, cause, approver_ids)

      trigger_code_owner_webhook_events(merge_request, was_approved, cause)
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

    def measure_duration(operation_name)
      return yield unless log_reset_approvals_duration_enabled?

      start_time = current_monotonic_time
      result = yield
      duration = (current_monotonic_time - start_time).round(Gitlab::InstrumentationHelper::DURATION_PRECISION)
      duration_statistics["#{operation_name}_duration_s"] = duration
      result
    end

    def measure_duration_accumulate(operation_name)
      return yield unless log_reset_approvals_duration_enabled?

      start_time = current_monotonic_time
      result = yield
      duration = (current_monotonic_time - start_time).round(Gitlab::InstrumentationHelper::DURATION_PRECISION)
      duration_statistics["#{operation_name}_duration_s"] ||= 0
      duration_statistics["#{operation_name}_duration_s"] += duration
      result
    end

    def duration_statistics
      @duration_statistics ||= {}
    end

    def log_reset_approvals_duration_enabled?
      Feature.enabled?(:log_merge_request_reset_approvals_duration, current_user)
    end
    strong_memoize_attr :log_reset_approvals_duration_enabled?

    def log_hash_metadata_on_done(hash)
      total_duration = hash.values.sum
      hash_with_total = hash.merge('reset_approvals_service_total_duration_s' => total_duration)

      Gitlab::AppJsonLogger.info(
        'event' => 'merge_requests_reset_approvals_service',
        **hash_with_total
      )
    end

    def current_monotonic_time
      Gitlab::Metrics::System.monotonic_time
    end
  end
end
