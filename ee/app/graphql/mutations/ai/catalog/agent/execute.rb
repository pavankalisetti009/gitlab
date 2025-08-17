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

          field :flow_config, GraphQL::Types::String,
            null: true,
            description: 'YAML configuration file that can be used in Duo workflow service for flow execution.'

          authorize :admin_ai_catalog_item

          def resolve(agent_id:, agent_version_id: nil)
            agent = authorized_find!(id: agent_id)

            agent_version = resolve_agent_version(agent, agent_version_id)

            authorize!(agent_version)

            result = ::Ai::Catalog::Agents::ExecuteService.new(agent, agent_version, current_user).execute

            { flow_config: result.payload[:flow_config], errors: result.errors }
          end

          private

          def resolve_agent_version(agent, agent_version_id)
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
