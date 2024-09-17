# frozen_string_literal: true

module Types
  module Members
    # rubocop: disable Graphql/AuthorizeTypes -- standard roles are readable for everyone
    class StandardRoleType < BaseObject
      graphql_name 'StandardRole'
      description 'Represents a standard role'

      include ::Gitlab::Utils::StrongMemoize
      include MemberRolesHelper

      field :access_level,
        GraphQL::Types::Int,
        null: false,
        description: 'Access level as a number.'

      field :name,
        GraphQL::Types::String,
        null: false,
        description: 'Access level as a string.'

      field :members_count,
        GraphQL::Types::Int,
        null: false,
        alpha: { milestone: '17.3' },
        description: 'Total number of members with the standard role.'

      field :details_path,
        GraphQL::Types::String,
        null: false,
        alpha: { milestone: '17.4' },
        description: 'URL path to the role details webpage.'

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
