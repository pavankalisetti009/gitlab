# frozen_string_literal: true

module MergeRequests
  class MergedWithPolicyViolationsAuditEventService
    include Gitlab::Utils::StrongMemoize

    attr_reader :merge_request

    def initialize(merge_request)
      @merge_request = merge_request
    end

    def execute
      return unless merge_request.merged?
      return if violations.empty?

      audit_context = {
        name: 'merge_request_merged_with_policy_violations',
        author: merged_by,
        scope: target_project,
        target: merge_request,
        message: "Merge request with title '#{merge_request.title}' was merged with " \
          "#{violations.count} security policy violation(s)",
        additional_details: audit_details
      }

      ::Gitlab::Audit::Auditor.audit(audit_context)
    end

    private

    def merged_by
      merge_request.metrics.merged_by || Gitlab::Audit::DeletedAuthor.new(id: -4, name: 'Unknown User')
    end

    def audit_details
      {
        merge_request_title: merge_request.title,
        merge_request_id: merge_request.id,
        merge_request_iid: merge_request.iid,
        merged_at: merge_request.merged_at,
        source_branch: merge_request.source_branch,
        target_branch: merge_request.target_branch,
        project_id: target_project.id,
        project_name: target_project.name,
        project_full_path: target_project.full_path,
        violated_policies: violated_policies,
        security_policy_approval_rules: policy_approval_rules,
        violation_details: violation_details
      }
    end

    # There can be violated policies which were skipped because of invalid rules
    # We collect both types here for visibility
    def wrapped_approval_rules
      approval_state.wrapped_approval_rules + approval_state.invalid_approvers_rules
    end

    def policy_approval_rules
      wrapped_approval_rules.filter_map do |wrapped_rule|
        next unless wrapped_rule.from_scan_result_policy?

        {
          name: wrapped_rule.name,
          report_type: wrapped_rule.report_type,
          approvals_required: wrapped_rule.approvals_required,
          approved: wrapped_rule.approved?,
          approved_approvers: wrapped_rule.approved_approvers.map(&:username).sort,
          invalid_rule: wrapped_rule.invalid_rule?,
          fail_open: wrapped_rule.fail_open?
        }
      end
    end

    def violation_details
      {
        fail_open_policies: details.fail_open_policies.as_json,
        fail_closed_policies: details.fail_closed_policies.as_json,
        warn_mode_policies: details.warn_mode_policies.as_json,
        new_scan_finding_violations: details.new_scan_finding_violations.as_json,
        previous_scan_finding_violations: details.previous_scan_finding_violations.as_json,
        license_scanning_violations: details.license_scanning_violations.as_json,
        any_merge_request_violations: details.any_merge_request_violations.as_json,
        errors: details.errors.as_json,
        comparison_pipelines: details.comparison_pipelines.as_json
      }
    end

    def violated_policies
      violations.filter_map do |violation|
        security_policy = violation.security_policy
        next unless security_policy

        policy_configuration = security_policy.security_orchestration_policy_configuration

        {
          policy_id: security_policy.id,
          policy_name: security_policy.name,
          policy_type: security_policy.type,
          security_orchestration_policy_configuration_id: policy_configuration.id,
          security_policy_management_project_id: policy_configuration.security_policy_management_project_id
        }
      end
    end

    def violations
      merge_request.scan_result_policy_violations
    end
    strong_memoize_attr :violations

    def target_project
      merge_request.project
    end
    strong_memoize_attr :target_project

    def approval_state
      ApprovalState.new(merge_request)
    end
    strong_memoize_attr :approval_state

    def details
      Security::ScanResultPolicies::PolicyViolationDetails.new(merge_request)
    end
    strong_memoize_attr :details
  end
end
