# frozen_string_literal: true

module Resolvers
  module Ai
    module DuoWorkflows
      class WorkflowEventsResolver < BaseResolver
        include Gitlab::Graphql::Authorize::AuthorizeResource

        authorizes_object!

        type Types::Ai::DuoWorkflows::WorkflowEventType, null: false

        argument :workflow_id, Types::GlobalIDType[::Ai::DuoWorkflows::Workflow],
          required: true,
          description: 'Array of request IDs to fetch.'

        def resolve(**args)
          return [] unless current_user

          if object.is_a?(::Project)
            project = object
            return [] unless current_user.can?(:duo_workflow, project)
          end

          Gitlab::Graphql::Lazy.with_value(find_object(id: args[:workflow_id])) do |workflow|
            if can_get_workflow_checkpoints?(workflow, project)
              workflow.checkpoints
            else
              []
            end
          end
        end

        private

        def find_object(id:)
          GitlabSchema.find_by_gid(id)
        end

        def can_get_workflow_checkpoints?(workflow, project)
          return false unless workflow

          return false unless Ability.allowed?(current_user, :read_duo_workflow, workflow)

          return false if project && workflow.project != project

          true
        end
      end
    end
  end
end
