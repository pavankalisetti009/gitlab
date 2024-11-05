# frozen_string_literal: true

module EE
  module Ci
    module JobTokenScope
      module UpdatePoliciesService
        extend ::Gitlab::Utils::Override

        override :execute
        def execute(target, policies)
          super.tap do |response|
            audit(project, target, current_user, policies) if response.success?
          end
        end

        private

        def audit(scope, target, author, policies)
          audit_message =
            "CI job token policies updated to: #{policies.join(', ')}"

          event_name = 'secure_ci_job_token_policies_updated'

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
