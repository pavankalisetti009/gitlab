# frozen_string_literal: true

module Types
  module SecretsManagement
    class ProjectSecretsPermissionType < BaseObject
      graphql_name 'SecretPermission'
      description 'Representation of a secrets permission.'

      include SecretsPermissionInterface

      authorize :read_project_secrets_manager

      field :project, Types::ProjectType,
        null: false,
        method: :resource,
        description: 'Project the secret permission belong to.'
    end
  end
end
