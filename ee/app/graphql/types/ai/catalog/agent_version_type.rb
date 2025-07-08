# frozen_string_literal: true

module Types
  module Ai
    module Catalog
      # rubocop: disable Graphql/AuthorizeTypes -- Permissions are still to be determined https://gitlab.com/gitlab-org/gitlab/-/issues/553928
      class AgentVersionType < ::Types::BaseObject
        graphql_name 'AiCatalogAgentVersion'
        description 'An AI catalog agent version'

        implements ::Types::Ai::Catalog::VersionInterface

        field :system_prompt, GraphQL::Types::String, null: true,
          description: 'System prompt for the agent.'
        field :user_prompt, GraphQL::Types::String, null: true,
          description: 'User prompt for the agent.'

        def system_prompt
          object.definition['system_prompt']
        end

        def user_prompt
          object.definition['user_prompt']
        end
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
