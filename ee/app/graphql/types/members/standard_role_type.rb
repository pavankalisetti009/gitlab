# frozen_string_literal: true

module Types
  module Members
    # rubocop: disable Graphql/AuthorizeTypes -- standard roles are readable for everyone
    class StandardRoleType < BaseObject
      graphql_name 'StandardRole'
      description 'Represents a standard role'

      include ::Gitlab::Utils::StrongMemoize
      include MemberRolesHelper

      implements Types::Members::RoleInterface

      field :access_level,
        GraphQL::Types::Int,
        null: false,
        description: 'Access level as a number.'

      def details_path
        access_level = object[:access_level]
        access_enum = access_enums[access_level].upcase

        group = object[:group]
        access_enum.define_singleton_method(:namespace) { group }

        member_role_details_path(access_enum)
      end

      def access_enums
        Types::MemberAccessLevelEnum.enum.invert
      end
      strong_memoize_attr :access_enums
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
