# frozen_string_literal: true

module Types
  module SecretsManagement
    module Permissions
      class PrincipalType < BaseObject # rubocop:disable Graphql/AuthorizeTypes -- This is not necessary because the superclass declares the authorization
        graphql_name 'Principal'
        description 'Representation of who is provided access to. For eg: User/Role/MemberRole/Group.'

        field :id, GraphQL::Types::ID,
          null: false,
          description: 'ID of the principal (User, MemberRole, Role, Group).'

        field :type, GraphQL::Types::String,
          null: false,
          description: 'Name of the principal (User, MemberRole, Role, Group).'

        field :user,
          Types::UserType,
          null: true,
          description: "User who is provided access to."

        field :user_role_id, GraphQL::Types::String,
          null: true,
          description: 'RoleID of the user.'

        field :group,
          Types::GroupType,
          null: true,
          description: "Group who is provided access to."

        def id
          object[:id] || object['id']
        end

        def type
          object[:type] || object['type']
        end

        def user
          return unless type == 'User'

          user_record
        end

        def user_role_id
          return unless type == 'User' && project_id

          ::Gitlab::Graphql::Lazy.with_value(user_record) do |user|
            next nil unless user

            user.max_member_access_for_project(project_id)&.to_s
          end
        end

        def group
          return unless type == 'Group'

          group_record
        end

        private

        def user_record
          @user_record ||= if type == 'User'
                             BatchLoader::GraphQL.for(id.to_i).batch do |user_ids, loader|
                               users = ::UsersFinder.new(current_user, ids: user_ids).execute
                               users.each { |user| loader.call(user.id, user) }
                             end
                           end
        end

        def group_record
          @group_record ||= if type == 'Group'
                              BatchLoader::GraphQL.for(id.to_i).batch do |group_ids, loader|
                                groups = GroupsFinder.new(current_user, ids: group_ids).execute
                                groups.each { |group| loader.call(group.id, group) }
                              end
                            end
        end

        def project_id
          @project_id ||= (object[:project_id] || object['project_id'])&.to_i
        end
      end
    end
  end
end
