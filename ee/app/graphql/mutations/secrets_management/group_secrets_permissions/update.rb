# frozen_string_literal: true

module Mutations
  module SecretsManagement
    module GroupSecretsPermissions
      class Update < BaseMutation
        graphql_name 'GroupSecretsPermissionUpdate'

        include ResolvesGroup
        include Helpers::ErrorMessagesHelpers

        authorize :configure_group_secrets_permission

        argument :group_path, GraphQL::Types::ID,
          required: true,
          description: 'Group to which the permissions are added.'

        argument :principal, Types::SecretsManagement::Permissions::PrincipalInputType,
          required: true,
          description: 'User/MemberRole/Role/Group that is provided access.'

        argument :permissions, [::GraphQL::Types::String],
          required: true,
          description: "Permissions to be provided. ['create', 'update', 'read', 'delete']."

        argument :expired_at, GraphQL::Types::ISO8601Date, required: false,
          description: "Expiration date for Secret Permission (optional)."

        field :secrets_permission, Types::SecretsManagement::GroupSecretsPermissionType,
          null: true,
          description: 'Secrets Permission that was created.'

        def resolve(group_path:, principal:, permissions:, expired_at: nil)
          group = authorized_find!(group_path: group_path)

          if Feature.disabled?(:group_secrets_manager, group)
            raise_resource_not_available_error!("`group_secrets_manager` feature flag is disabled.")
          end

          principal_id = resolve_principal_id(principal)

          result = ::SecretsManagement::GroupSecretsPermissions::UpdateService
            .new(group, current_user)
            .execute(
              principal_id: principal_id,
              principal_type: principal.type,
              permissions: permissions,
              expired_at: expired_at
            )

          if result.success?
            {
              secrets_permission: result.payload[:secrets_permission],
              errors: []
            }
          else
            {
              secrets_permission: nil,
              errors: error_messages(result, [:secrets_permission])
            }
          end
        end

        private

        def resolve_principal_id(principal)
          unless principal.type == ::SecretsManagement::BaseSecretsPermission::PRINCIPAL_TYPES[:group]
            return principal.id
          end

          # NOTE: Accepting id here is only temporary for backwards compatibility. Will remove it as soon as project
          # secrets permissions have been migrated to accept group_path.
          return principal.id unless principal.id.blank?

          resolved_group = find_group_by_path(principal.group_path)
          return resolved_group.id if resolved_group

          raise Gitlab::Graphql::Errors::ArgumentError,
            "Group '#{principal.group_path}' not found"
        end

        def find_object(group_path:)
          resolve_group(full_path: group_path)
        end

        def find_group_by_path(full_path)
          ::Group.find_by_full_path(full_path)
        end
      end
    end
  end
end
