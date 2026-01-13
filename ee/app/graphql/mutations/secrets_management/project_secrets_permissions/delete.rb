# frozen_string_literal: true

module Mutations
  module SecretsManagement
    module ProjectSecretsPermissions
      class Delete < BaseMutation
        graphql_name 'ProjectSecretsPermissionDelete'

        include ResolvesProject
        include ::SecretsManagement::MutationErrorHandling

        authorize :admin_project_secrets_manager

        argument :project_path, GraphQL::Types::ID,
          required: true,
          description: 'Project from which the permissions are removed.'

        argument :principal, Types::SecretsManagement::Permissions::PrincipalInputType,
          required: true,
          description: 'User/MemberRole/Role/Group whose access is being removed.'

        field :secrets_permission, Types::SecretsManagement::ProjectSecretsPermissionType,
          null: true,
          description: 'Secrets Permission that was deleted.'

        def resolve(project_path:, principal:)
          project = authorized_find!(project_path: project_path)

          result = ::SecretsManagement::ProjectSecretsPermissions::DeleteService
            .new(project, current_user)
            .execute(
              principal_id: principal.id,
              principal_type: principal.type
            )

          if result.success?
            {
              secrets_permission: result.payload[:secrets_permission],
              errors: []
            }
          else
            {
              secrets_permission: nil,
              errors: [result.message]
            }
          end
        end

        private

        def find_object(project_path:)
          resolve_project(full_path: project_path)
        end
      end
    end
  end
end
