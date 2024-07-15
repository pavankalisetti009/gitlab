# frozen_string_literal: true

module Types
  module Ci
    # rubocop: disable Graphql/AuthorizeTypes -- Authentication at another location
    class PipelineManualVariableType < BaseObject
      graphql_name 'PipelineManualVariable'
      description 'CI/CD variables added to a manual pipeline.'

      field :id, GraphQL::Types::ID,
        null: false,
        description: 'ID of the variable.'

      field :key, GraphQL::Types::String,
        null: true,
        description: 'Name of the variable.'

      field :value, GraphQL::Types::String,
        null: true,
        description: 'Value of the variable.'
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
