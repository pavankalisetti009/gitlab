# frozen_string_literal: true

module EE
  module MergeRequests
    module PostMergeService
      extend ::Gitlab::Utils::Override
      include ::Security::ScanResultPolicies::PolicyLogger

      override :execute
      def execute(merge_request, source = nil)
        super
        ApprovalRules::FinalizeService.new(merge_request).execute

        target_project = merge_request.target_project
        if compliance_violations_enabled?(target_project.namespace)
          ComplianceManagement::MergeRequests::ComplianceViolationsWorker.perform_async(merge_request.id)
        end

        merge_request.approval_state.expire_unapproved_key!

        audit_approval_rules(merge_request)

        if current_user.project_bot?
          log_audit_event(merge_request, 'merge_request_merged_by_project_bot',
            "Merged merge request #{merge_request.title}")
        end

        sync_security_scan_orchestration_policies(target_project)
        trigger_blocked_merge_requests_merge_status_updated(merge_request)
        track_policies_fallback_behavior(merge_request)
        track_policies_running_violations(merge_request)
        publish_event_store_event(merge_request)
      end

      private

      def publish_event_store_event(merge_request)
        ::Gitlab::EventStore.publish ::MergeRequests::MergedEvent.new(data: { merge_request_id: merge_request.id })
      end

      def compliance_violations_enabled?(group)
        group.licensed_feature_available?(:group_level_compliance_dashboard)
      end

      def audit_approval_rules(merge_request)
        invalid_rules = merge_request.invalid_approvers_rules

        track_invalid_approvers(merge_request) if invalid_rules.present?

        invalid_rules.each do |rule|
          audit_invalid_rule(merge_request, rule)
        end
      end

      def track_invalid_approvers(merge_request)
        ::Gitlab::UsageDataCounters::MergeRequestActivityUniqueCounter
          .track_invalid_approvers(merge_request: merge_request)
      end

      def audit_invalid_rule(merge_request, rule)
        audit_context = {
          name: 'merge_request_invalid_approver_rules',
          author: merge_request.author,
          scope: project,
          target: merge_request,
          message: 'Invalid merge request approver rules',
          target_details: {
            title: merge_request.title,
            iid: merge_request.iid,
            id: merge_request.id,
            rule_type: rule.rule_type,
            rule_name: rule.name
          }
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      def sync_security_scan_orchestration_policies(project)
        return unless project.licensed_feature_available?(:security_orchestration_policies)

        Security::OrchestrationPolicyConfiguration
          .for_management_project(project)
          .each do |configuration|
          Security::SyncScanPoliciesWorker.perform_async(configuration.id)
        end
      end

      def track_policies_fallback_behavior(merge_request)
        return unless project.licensed_feature_available?(:security_orchestration_policies)

        Security::ScanResultPolicies::FallbackBehaviorTrackingWorker.perform_async(merge_request.id)
      end

      def track_policies_running_violations(merge_request)
        return unless project.licensed_feature_available?(:security_orchestration_policies)

        violations = merge_request.running_scan_result_policy_violations
        return if violations.none?

        log_policy_evaluation('post_merge', 'Running scan result policy violations after merge',
          project: project,
          merge_request_id: merge_request.id,
          merge_request_iid: merge_request.iid,
          head_pipeline_id: merge_request.diff_head_pipeline&.id,
          violation_ids: violations.map(&:id),
          scan_result_policy_ids: violations.map(&:scan_result_policy_id),
          approval_policy_rule_ids: violations.map(&:approval_policy_rule_id)
        )
      end

      def trigger_blocked_merge_requests_merge_status_updated(merge_request)
        merge_request.blocked_merge_requests.find_each do |blocked_mr|
          ::GraphqlTriggers.merge_request_merge_status_updated(blocked_mr)

          ::Gitlab::EventStore.publish(
            ::MergeRequests::UnblockedStateEvent.new(
              data: { current_user_id: current_user.id, merge_request_id: blocked_mr.id }
            )
          )
        end
      end
    end
  end
end
