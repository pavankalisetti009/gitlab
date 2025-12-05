# frozen_string_literal: true

module Mutations
  module SecretsManagement
    module GroupSecretsPermissions
      class Delete < BaseMutation
        graphql_name 'GroupSecretsPermissionDelete'

        include ResolvesGroup
        include ::SecretsManagement::MutationErrorHandling

        authorize :configure_group_secrets_permission

        argument :group_path, GraphQL::Types::ID,
          required: true,
          description: 'Group permissions for the secret.'

        argument :principal, Types::SecretsManagement::Permissions::PrincipalInputType,
          required: true,
          description: 'Whose permission to be deleted.'

        field :secrets_permission, Types::SecretsManagement::GroupSecretsPermissionType,
          null: true,
          description: 'Deleted Secrets Permission.'

        def resolve(group_path:, principal:)
          group = authorized_find!(group_path: group_path)

          if Feature.disabled?(:group_secrets_manager, group)
            raise_resource_not_available_error!("`group_secrets_manager` feature flag is disabled.")
          end

          result = ::SecretsManagement::GroupSecretsPermissions::DeleteService
            .new(group, current_user)
            .execute(principal: { type: principal.type, id: principal.id })

          if result.success?
            {
              secrets_permission: result.payload[:secret_permission],
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

        def find_object(group_path:)
          resolve_group(full_path: group_path)
        end
      end
    end
  end
end
