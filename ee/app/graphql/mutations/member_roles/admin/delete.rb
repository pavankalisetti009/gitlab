# frozen_string_literal: true

module Mutations
  # rubocop:disable Gitlab/BoundedContexts -- the MemberRole module already exists and holds the other mutations as well
  module MemberRoles
    module Admin
      class Delete < Base
        graphql_name 'MemberRoleAdminDelete'

        authorize :admin_member_role

        argument :id, ::Types::GlobalIDType[::MemberRole],
          required: true,
          description: 'ID of the admin member role to delete.'

        def resolve(**args)
          member_role = authorized_find!(id: args.delete(:id))

          unless member_role.admin_related_role?
            raise Gitlab::Graphql::Errors::ArgumentError, 'This mutation is restricted to deleting admin roles only'
          end

          response = ::MemberRoles::DeleteService.new(current_user).execute(member_role)

          {
            member_role: response.payload[:member_role],
            errors: response.errors
          }
        end
      end
    end
  end
  # rubocop:enable Gitlab/BoundedContexts
end
