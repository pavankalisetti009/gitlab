# frozen_string_literal: true

module EE
  module Ci
    module JobTokenScope
      module AddProjectService
        extend ::Gitlab::Utils::Override

        override :execute
        def execute(target_project, policies: [], direction: :inbound)
          super.tap do |response|
            audit(project, target_project, current_user, policies) if direction == :inbound && response.success?
          end
        end

        private

        def audit(scope, target, author, policies)
          audit_message =
            "Project #{target.full_path} was added to inbound list of allowed projects for #{scope.full_path}"
          event_name = 'secure_ci_job_token_project_added'

          if ::Feature.enabled?(:add_policies_to_ci_job_token, scope) && policies.present?
            audit_message += ", with job token permissions: #{policies.join(', ')}"
          end

          audit_context = {
            name: event_name,
            author: author,
            scope: scope,
            target: target,
            message: audit_message
          }

          ::Gitlab::Audit::Auditor.audit(audit_context)
        end
      end
    end
  end
end
