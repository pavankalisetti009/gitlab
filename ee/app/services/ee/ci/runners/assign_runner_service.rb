# frozen_string_literal: true

module EE
  module Ci
    module Runners
      module AssignRunnerService
        extend ::Gitlab::Utils::Override

        override :execute
        def execute
          super.tap do |result|
            audit_event if result.success?
          end
        end

        private

        AUDIT_MESSAGE = 'Assigned CI runner to project'

        def audit_event
          return if quiet

          ::AuditEvents::RunnerCustomAuditEventService.new(runner, user, project, AUDIT_MESSAGE).track_event
        end
      end
    end
  end
end
