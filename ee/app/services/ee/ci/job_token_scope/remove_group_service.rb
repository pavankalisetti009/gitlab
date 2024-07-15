# frozen_string_literal: true

module EE
  module Ci
    module JobTokenScope
      module RemoveGroupService
        extend ::Gitlab::Utils::Override

        override :execute
        def execute(target_group)
          super.tap do |response|
            audit(project, target_group, current_user) if response.success?
          end
        end

        private

        def audit(scope, target, author)
          audit_message =
            "Group #{target.full_path} was removed from list of allowed groups for #{scope.full_path}"
          event_name = 'secure_ci_job_token_group_removed'

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
