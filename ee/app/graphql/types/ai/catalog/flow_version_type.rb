# frozen_string_literal: true

module Types
  module Ai
    module Catalog
      class FlowVersionType < ::Types::BaseObject
        graphql_name 'AiCatalogFlowVersion'
        description 'An AI catalog flow version'
        authorize :read_ai_catalog_item

        field :steps, FlowStepsType.connection_type,
          method: :def_steps,
          null: false,
          description: 'Steps of the flow.'

        implements ::Types::Ai::Catalog::VersionInterface
      end
    end
  end
end
