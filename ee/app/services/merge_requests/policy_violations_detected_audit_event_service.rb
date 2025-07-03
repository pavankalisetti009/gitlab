# frozen_string_literal: true

module MergeRequests
  class PolicyViolationsDetectedAuditEventService
    include Gitlab::Utils::StrongMemoize

    def initialize(merge_request)
      @merge_request = merge_request
    end

    def execute
      return if violations.blank? || violations.running.any?

      ::Gitlab::Audit::Auditor.audit(audit_context)
    end

    private

    attr_reader :merge_request

    def violations
      merge_request.scan_result_policy_violations
    end
    strong_memoize_attr :violations

    def target_project
      @_target_project ||= merge_request.project
    end

    def details
      @_details ||= ::Security::ScanResultPolicies::PolicyViolationDetails.new(merge_request)
    end

    def audit_context
      {
        name: 'policy_violations_detected',
        message: "#{violations.count} merge request approval policy violation(s) detected in merge request " \
          "with title '#{merge_request.title}'",
        author: merge_request.author,
        scope: target_project,
        target: merge_request,
        additional_details: additional_details
      }
    end

    def additional_details
      {
        merge_request_title: merge_request.title,
        merge_request_id: merge_request.id,
        merge_request_iid: merge_request.iid,
        source_branch: merge_request.source_branch,
        target_branch: merge_request.target_branch,
        project_id: target_project.id,
        project_name: target_project.name,
        project_full_path: target_project.full_path,
        violated_policies: violated_policies,
        violation_details: violation_details
      }
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
  end
end
