# frozen_string_literal: true

module EE
  module Ci
    module Runners
      # Unregisters a CI Runner and logs an audit event
      #
      module UnregisterRunnerService
        extend ::Gitlab::Utils::Override

        override :execute
        def execute
          scopes = runner_scopes # Save the scopes before destroying the record

          super.tap { audit_event(scopes) }
        end

        private

        def runner_scopes
          case runner.runner_type
          when 'group_type'
            runner.groups.to_a
          when 'project_type'
            runner.projects.to_a
          else
            [::Gitlab::Audit::InstanceScope.new]
          end
        end

        def audit_event(scopes)
          scopes.each do |scope|
            ::AuditEvents::UnregisterRunnerAuditEventService.new(runner, author, scope).track_event
          end
        end
      end
    end
  end
end
