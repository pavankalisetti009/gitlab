# frozen_string_literal: true

module Types
  module WorkItems
    module WidgetDefinitions
      # rubocop:disable Graphql/AuthorizeTypes -- Authorization too granular, parent type is authorized
      class HealthStatusType < BaseObject
        graphql_name 'WorkItemWidgetDefinitionHealthStatus'
        description 'Represents a health status widget definition'

        implements Types::WorkItems::WidgetDefinitionInterface

        field :editable, GraphQL::Types::Boolean,
          null: false,
          description: 'Indicates whether editable health status is available.'

        field :roll_up, GraphQL::Types::Boolean,
          null: false,
          description: 'Indicates whether rolled up health status is available.'

        def editable
          true
        end

        def roll_up
          false
        end
      end
      # rubocop:enable Graphql/AuthorizeTypes
    end
  end
end
