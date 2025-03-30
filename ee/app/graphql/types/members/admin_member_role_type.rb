# frozen_string_literal: true

module Types
  module Members
    class AdminMemberRoleType < BaseObject
      graphql_name 'AdminMemberRole'
      description 'Represents an admin member role'
      include MemberRolesHelper

      implements Types::Members::RoleInterface

      authorize :read_member_role

      field :enabled_permissions,
        ::Types::Members::CustomizableAdminPermissionType.connection_type,
        null: false,
        experiment: { milestone: '17.7' },
        description: 'Array of all permissions enabled for the custom role.'

      field :edit_path,
        GraphQL::Types::String,
        null: false,
        experiment: { milestone: '16.11' },
        description: 'Web UI path to edit the custom role.'

      field :created_at,
        Types::TimeType,
        null: false,
        description: 'Timestamp of when the member role was created.'

      def members_count
        return object.members_count if object.respond_to?(:members_count)

        object.members.count
      end

      def users_count
        object.user_member_roles.count
      end

      def edit_path
        member_role_edit_path(object)
      end

      def details_path
        member_role_details_path(object)
      end

      def enabled_permissions
        object.enabled_admin_permissions.keys
      end
    end
  end
end
