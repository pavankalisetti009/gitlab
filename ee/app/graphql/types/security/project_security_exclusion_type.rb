# frozen_string_literal: true

module Types
  module Security
    # rubocop: disable Graphql/AuthorizeTypes -- The resolver authorizes the request
    class ProjectSecurityExclusionType < BaseObject
      graphql_name 'ProjectSecurityExclusion'
      description 'Represents a project-level security scanner exclusion'

      field :id, GraphQL::Types::ID,
        null: false,
        description: 'ID of the exclusion.'

      field :scanner, Types::Security::ExclusionScannerEnum,
        null: false,
        description: 'Security scanner the exclusion will be used for.'

      field :type, Types::Security::ExclusionTypeEnum,
        null: false,
        description: 'Type of the exclusion.'

      field :value, GraphQL::Types::String,
        null: false,
        description: 'Value of the exclusion.'

      field :description, GraphQL::Types::String,
        null: true,
        description: 'Optional description for the exclusion.'

      field :active, GraphQL::Types::Boolean,
        null: false,
        description: 'Whether the exclusion is active.'
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
