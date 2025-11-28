# frozen_string_literal: true

module Types
  module Ai
    module Catalog
      class AgentType < ::Types::BaseObject
        graphql_name 'AiCatalogAgent'
        description 'An AI catalog agent'
        authorize :read_ai_catalog_item

        implements ::Types::Ai::Catalog::ItemInterface

        field :foundational,
          GraphQL::Types::Boolean,
          null: false,
          description: 'Whether the item is a foundational agent (only on GitLab SaaS).'
      end
    end
  end
end
