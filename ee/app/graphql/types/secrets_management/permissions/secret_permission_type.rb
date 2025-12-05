# frozen_string_literal: true

module Types
  module SecretsManagement
    module Permissions
      class SecretPermissionType < BaseObject
        graphql_name 'SecretPermission'
        description 'Representation of a secret permission.'

        include SecretsPermissionInterface

        authorize :read_project_secrets_manager

        field :project, Types::ProjectType,
          null: false,
          method: :resource,
          description: 'Project the secret permission belong to.'
      end
    end
  end
end
