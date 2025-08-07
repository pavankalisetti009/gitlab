# frozen_string_literal: true

module Mutations
  module Ai
    module FlowTriggers
      class Update < BaseMutation
        graphql_name 'AiFlowTriggerUpdate'

        authorize :manage_ai_flow_triggers

        argument :id, ::Types::GlobalIDType[::Ai::FlowTrigger],
          required: true,
          description: 'ID of the flow trigger to update.'

        argument :user_id, ::Types::GlobalIDType[::User],
          prepare: ->(global_id, _ctx) { global_id.model_id.to_i },
          required: false,
          description: 'Owner of the AI flow trigger.'

        argument :description, GraphQL::Types::String,
          required: false,
          description: 'Description of the AI flow trigger.'

        argument :event_types, [GraphQL::Types::Int],
          required: false,
          description: 'Event types that triggers the AI flow.'

        argument :config_path, GraphQL::Types::String,
          required: false,
          description: 'Path to the configuration file for the AI flow trigger.'

        field :ai_flow_trigger,
          Types::Ai::FlowTriggerType,
          description: 'Updated AI flow trigger.'

        def resolve(id:, **params)
          trigger = authorized_find!(id: id)

          if trigger.update(params)
            {
              ai_flow_trigger: trigger,
              errors: []
            }
          else
            {
              ai_flow_trigger: nil,
              errors: trigger.errors
            }
          end
        end
      end
    end
  end
end
