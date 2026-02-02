# frozen_string_literal: true

module Types
  module SecretsManagement
    class GroupSecretType < BaseObject
      graphql_name 'GroupSecret'
      description 'Represents a group secret'

      authorize :read_secret

      field :group,
        Types::GroupType,
        null: false,
        description: 'Group the secret belongs to.'

      field :name,
        type: GraphQL::Types::String,
        null: false,
        description: 'Name of the group secret.'

      field :description,
        type: GraphQL::Types::String,
        null: true,
        description: 'Description of the group secret.'

      field :environment,
        type: GraphQL::Types::String,
        null: false,
        description: 'Environments that can access the secret.'

      field :protected, GraphQL::Types::Boolean,
        null: false,
        description: 'Whether the secret is only accessible from protected branches.'

      field :metadata_version,
        type: GraphQL::Types::Int,
        null: true,
        description: 'Current metadata version of the group secret.'

      field :status, SecretStatusEnum, null: false,
        description: 'Computed lifecycle status of the secret, based on timestamps.'
    end
  end
end
