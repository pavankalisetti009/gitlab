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
          null: true,
          description: 'Steps of the flow.'

        field :definition, GraphQL::Types::String,
          null: true,
          description: 'YAML definition of the flow.'

        implements ::Types::Ai::Catalog::VersionInterface

        def definition
          object.definition['yaml_definition']
        end
      end
    end
  end
end
