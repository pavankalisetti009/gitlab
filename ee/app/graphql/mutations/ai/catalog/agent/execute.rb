# frozen_string_literal: true

module Mutations
  module Ai
    module Catalog
      module Agent
        class Execute < BaseMutation
          graphql_name 'AiCatalogAgentExecute'

          argument :agent_id, ::Types::GlobalIDType[::Ai::Catalog::Item],
            required: true,
            description: 'Global ID of the AI catalog agent to execute.'

          argument :agent_version_id, ::Types::GlobalIDType[::Ai::Catalog::ItemVersion],
            required: false,
            description: 'Global ID of the specific agent version to use. If not provided,
                        the latest version will be used.'

          argument :user_prompt, GraphQL::Types::String,
            required: true,
            description: 'User prompt that will be used for agent execution.'

          field :flow_config, GraphQL::Types::String,
            null: true,
            description: 'YAML configuration that can be used in Duo workflow service for flow execution.'

          field :workflow, Types::Ai::DuoWorkflows::WorkflowType,
            null: true,
            description: 'Created workflow.'

          authorize :execute_ai_catalog_item_version

          def resolve(agent_id:, agent_version_id: nil, user_prompt: nil)
            agent = GitlabSchema.object_from_id(agent_id).sync
            agent_version = authorized_find!(agent:, agent_version_id:)

            result = ::Ai::Catalog::Agents::ExecuteService.new(
              project: agent.project,
              current_user: current_user,
              params: { agent: agent, agent_version: agent_version, execute_workflow: true, user_prompt: user_prompt }
            ).execute
            {
              flow_config: result.payload[:flow_config],
              workflow: result.payload[:workflow],
              errors: result.errors
            }
          end

          private

          def find_object(agent:, agent_version_id:)
            return if agent.nil?

            if agent_version_id.present?
              GitlabSchema.object_from_id(agent_version_id).sync
            else
              agent.latest_version
            end
          end
        end
      end
    end
  end
end
