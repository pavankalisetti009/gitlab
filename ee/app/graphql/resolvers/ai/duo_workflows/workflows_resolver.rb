# frozen_string_literal: true

module Resolvers
  module Ai
    module DuoWorkflows
      class WorkflowsResolver < BaseResolver
        type Types::Ai::DuoWorkflows::WorkflowType, null: false

        def resolve(**_args)
          return [] unless current_user

          ::Ai::DuoWorkflows::Workflow.for_user(current_user.id)
        end
      end
    end
  end
end
