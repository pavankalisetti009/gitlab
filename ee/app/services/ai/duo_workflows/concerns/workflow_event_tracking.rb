# frozen_string_literal: true

module Ai
  module DuoWorkflows
    module Concerns
      module WorkflowEventTracking
        extend ActiveSupport::Concern
        include ::Gitlab::InternalEventsTracking

        private

        def track_workflow_event(event_name, workflow)
          track_internal_event(
            event_name,
            user: workflow.user,
            project: workflow.project,
            additional_properties: workflow_tracking_properties(workflow)
          )
        end

        def workflow_tracking_properties(workflow)
          {
            label: workflow.workflow_definition,
            value: workflow.id,
            property: workflow.environment
          }
        end
      end
    end
  end
end
