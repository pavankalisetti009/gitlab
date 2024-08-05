# frozen_string_literal: true

module Types
  module Members
    # rubocop: disable Graphql/AuthorizeTypes -- standard roles are readable for everyone
    class StandardRoleType < BaseObject
      graphql_name 'StandardRole'
      description 'Represents a standard role'

      field :access_level,
        GraphQL::Types::Int,
        null: false,
        description: 'Access level as a number.'

      field :name,
        GraphQL::Types::String,
        null: false,
        description: 'Access level as a string.'

      field :members_count,
        GraphQL::Types::Int,
        null: false,
        alpha: { milestone: '17.3' },
        description: 'Total number of members with the standard role.'
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
