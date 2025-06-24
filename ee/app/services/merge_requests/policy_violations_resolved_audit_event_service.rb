# frozen_string_literal: true

module MergeRequests
  class PolicyViolationsResolvedAuditEventService
    include Gitlab::Utils::StrongMemoize

    def initialize(merge_request)
      @merge_request = merge_request
    end

    def execute
      return if violations.any?

      ::Gitlab::Audit::Auditor.audit(audit_context)
    end

    private

    attr_reader :merge_request

    def violations
      merge_request.scan_result_policy_violations
    end
    strong_memoize_attr :violations

    def merge_request_project
      merge_request.project
    end
    strong_memoize_attr :merge_request_project

    def policy_configuration
      merge_request_project.security_orchestration_policy_configuration
    end
    strong_memoize_attr :policy_configuration

    def audit_context
      {
        name: 'policy_violations_resolved',
        message: "All merge request approval policy violation(s) resolved " \
          "in merge request with title '#{merge_request.title}' in '#{merge_request_project.name}' project",
        author: merge_request.author,
        scope: policy_configuration&.security_policy_management_project,
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
        project_id: merge_request_project.id,
        project_name: merge_request_project.name,
        project_full_path: merge_request_project.full_path,
        security_policy_management_project_id: policy_configuration&.security_policy_management_project_id
      }
    end
  end
end
