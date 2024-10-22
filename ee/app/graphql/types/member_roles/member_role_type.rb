# frozen_string_literal: true

module Types
  module MemberRoles
    # Anyone who can update group/project members can also read member roles
    # But it is too complex to be included on a simple MemberRole type
    #
    # rubocop: disable Graphql/AuthorizeTypes -- authorization too complex
    class MemberRoleType < BaseObject
      graphql_name 'MemberRole'
      description 'Represents a member role'

      include MemberRolesHelper

      field :id,
        ::Types::GlobalIDType[::MemberRole],
        null: false,
        description: 'ID of the member role.'

      field :name,
        GraphQL::Types::String,
        null: false,
        description: 'Name of the member role.'

      field :description,
        GraphQL::Types::String,
        null: true,
        description: 'Description of the member role.'

      field :base_access_level,
        Types::AccessLevelType,
        null: false,
        alpha: { milestone: '16.5' },
        description: 'Base access level for the custom role.'

      field :enabled_permissions,
        ::Types::MemberRoles::CustomizablePermissionType.connection_type,
        null: false,
        alpha: { milestone: '16.5' },
        description: 'Array of all permissions enabled for the custom role.'

      field :members_count,
        GraphQL::Types::Int,
        alpha: { milestone: '16.7' },
        description: 'Number of times the role has been directly assigned to a group or project member.'

      field :users_count,
        GraphQL::Types::Int,
        alpha: { milestone: '17.5' },
        description: 'Number of users who have been directly assigned the role in at least one group or project.'

      field :edit_path,
        GraphQL::Types::String,
        null: false,
        alpha: { milestone: '16.11' },
        description: 'Web UI path to edit the custom role.'

      field :details_path,
        GraphQL::Types::String,
        null: false,
        alpha: { milestone: '17.4' },
        description: 'URL path to the role details webpage.'

      field :created_at,
        Types::TimeType,
        null: false,
        description: 'Timestamp of when the member role was created.'

      def members_count
        return object.members_count if object.respond_to?(:members_count)

        object.members.count
      end

      def users_count
        object.users_count if object.respond_to?(:users_count)

        object.users.count
      end

      def edit_path
        member_role_edit_path(object)
      end

      def details_path
        member_role_details_path(object)
      end
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
