# frozen_string_literal: true

module Types
  module SecretsManagement
    class ProjectSecretsManagerType < BaseObject
      graphql_name 'ProjectSecretsManager'
      description 'Representation of a project secrets manager.'

      authorize :read_project_secrets_manager_status

      field :project,
        Types::ProjectType,
        null: false,
        description: 'Project the secrets manager belong to.'

      field :status,
        Types::SecretsManagement::ProjectSecretsManagerStatusEnum,
        description: 'Status of the project secrets manager.'
    end
  end
end
