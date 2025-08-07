# frozen_string_literal: true

module Mutations
  module Ai
    module FlowTriggers
      class Delete < BaseMutation
        graphql_name 'AiFlowTriggerDelete'

        authorize :manage_ai_flow_triggers

        argument :id, ::Types::GlobalIDType[::Ai::FlowTrigger],
          required: true,
          description: 'ID of the flow trigger to delete.'

        def resolve(id:)
          trigger = authorized_find!(id: id)

          if trigger.destroy
            {
              errors: []
            }
          else
            {
              errors: ['Failed to delete the flow trigger']
            }
          end
        end
      end
    end
  end
end
