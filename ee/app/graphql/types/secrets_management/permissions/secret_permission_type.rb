# frozen_string_literal: true

module Types
  module SecretsManagement
    module Permissions
      class SecretPermissionType < BaseObject
        graphql_name 'SecretPermission'
        description 'Representation of a secrets permission.'

        authorize :admin_project_secrets_manager

        field :project,
          Types::ProjectType,
          null: false,
          description: 'Project the secret permission belong to.'

        field :principal,
          Types::SecretsManagement::Permissions::PrincipalType,
          null: false,
          description: 'Who is provided access to. For eg: User/Role/MemberRole/Group.'

        field :permissions,
          type: GraphQL::Types::String,
          null: false,
          description: "Permissions to be provided. ['create', 'update', 'read', 'delete']."

        field :granted_by,
          Types::UserType,
          null: true,
          description: "User who created the Secret Permission."

        field :expired_at,
          type: GraphQL::Types::ISO8601Date,
          null: true,
          description: "Expiration date for Secret Permission (optional)."

        def principal
          {
            id: object.principal_id.to_s,
            type: object.principal_type.to_s,
            project_id: object.project.id.to_s
          }
        end

        def granted_by
          BatchLoader::GraphQL.for(object.granted_by).batch do |user_ids, loader|
            users = ::UsersFinder.new(current_user, ids: user_ids).execute
            users.each { |user| loader.call(user.id, user) }
          end
        end
      end
    end
  end
end
