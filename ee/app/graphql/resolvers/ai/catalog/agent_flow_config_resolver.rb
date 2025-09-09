# frozen_string_literal: true

module Resolvers
  module Ai
    module Catalog
      class AgentFlowConfigResolver < BaseResolver
        type ::GraphQL::Types::String, null: true

        argument :agent_id, ::Types::GlobalIDType[::Ai::Catalog::Item],
          required: true,
          description: 'Global ID of the AI catalog agent.'

        argument :agent_version_id, ::Types::GlobalIDType[::Ai::Catalog::ItemVersion],
          required: false,
          description: 'Global ID of the specific agent version to use. If not provided, ' \
            'the latest version will be used.'

        argument :flow_config_type, Types::Ai::Catalog::FlowConfigTypeEnum,
          required: true,
          description: 'Type of flow configuration to generate.'

        def resolve(agent_id:, flow_config_type:, agent_version_id: nil)
          agent = GitlabSchema.object_from_id(agent_id).sync

          return unless Ability.allowed?(current_user, :read_ai_catalog_item, agent)

          agent_version = resolve_agent_version(agent, agent_version_id)

          return unless agent_version.present?

          result = ::Ai::Catalog::Agents::BuildFlowConfigService.new(
            project: agent.project,
            current_user: current_user,
            params: {
              agent: agent,
              agent_version: agent_version,
              flow_config_type: flow_config_type
            }
          ).execute

          result.payload[:flow_config]
        end

        private

        def resolve_agent_version(agent, agent_version_id)
          return agent.latest_version unless agent_version_id.present?

          agent_version = GitlabSchema.object_from_id(agent_version_id).sync

          return unless agent_version.present? && agent_version.item == agent

          agent_version
        end
      end
    end
  end
end
