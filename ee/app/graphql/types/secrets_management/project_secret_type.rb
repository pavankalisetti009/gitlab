# frozen_string_literal: true

module Types
  module SecretsManagement
    class ProjectSecretType < BaseObject
      graphql_name 'ProjectSecret'
      description 'Representation of a project secret.'

      authorize :read_project_secrets

      field :project,
        Types::ProjectType,
        null: false,
        description: 'Project the secret belong to.'

      field :name,
        type: GraphQL::Types::String,
        null: false,
        description: 'Name of the project secret.'

      field :description,
        type: GraphQL::Types::String,
        null: true,
        description: 'Description of the project secret.'

      field :environment,
        type: GraphQL::Types::String,
        null: false,
        description: 'Environments that can access the secret.'

      field :branch,
        type: GraphQL::Types::String,
        null: false,
        description: 'Branches that can access the secret.'

      field :rotation_info,
        type: SecretRotationInfoType,
        null: true,
        description: 'Rotation configuration for the secret.'

      field :metadata_version,
        type: GraphQL::Types::Int,
        null: true,
        description: 'Current metadata version of the project secret.'

      field :status, ProjectSecretStatusEnum, null: false,
        description: 'Computed lifecycle status of the secret, based on timestamps.'
    end
  end
end
