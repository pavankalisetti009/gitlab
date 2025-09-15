# frozen_string_literal: true

module Types
  module Ai
    module Catalog
      # rubocop:disable Graphql/AuthorizeTypes -- authorization occurs at parent level
      class FlowStepsType < ::Types::BaseObject
        graphql_name 'AiCatalogFlowSteps'

        field :agent, AgentType,
          null: true,
          description: 'Agent used.'

        field :pinned_version_prefix, GraphQL::Types::String,
          null: true,
          description: 'Major version, minor version, or patch the agent is pinned to.'

        def agent
          ::Gitlab::Graphql::Loaders::BatchModelLoader.new(::Ai::Catalog::Item, object['agent_id']).find
        end
      end
      # rubocop:enable Graphql/AuthorizeTypes
    end
  end
end
