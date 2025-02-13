# frozen_string_literal: true

module ComplianceManagement
  module ComplianceRequirements
    class ProjectFields
      FIELD_MAPPINGS = {
        'default_branch_protected' => :default_branch_protected?,
        'merge_request_prevent_author_approval' => :merge_request_prevent_author_approval?,
        'merge_request_prevent_committers_approval' => :merge_requests_disable_committers_approval?,
        'project_visibility' => :project_visibility,
        'minimum_approvals_required' => :minimum_approvals_required
      }.freeze

      class << self
        def map_field(project, field)
          method_name = FIELD_MAPPINGS[field]
          send(method_name, project) # rubocop:disable GitlabSecurity/PublicSend -- We control the `method` name
        end

        private

        def default_branch_protected?(project)
          ProtectedBranch.protected?(project, project.default_branch)
        end

        def merge_request_prevent_author_approval?(project)
          !project.merge_requests_author_approval?
        end

        def merge_requests_disable_committers_approval?(project)
          project.merge_requests_disable_committers_approval?
        end

        def project_visibility(project)
          project.visibility
        end

        def minimum_approvals_required(project)
          project.approval_rules.pick("SUM(approvals_required)") || 0
        end
      end
    end
  end
end
