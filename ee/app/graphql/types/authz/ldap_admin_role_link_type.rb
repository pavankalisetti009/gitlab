# frozen_string_literal: true

module Types
  module Authz
    # rubocop: disable Graphql/AuthorizeTypes -- authorizes in resolver
    class LdapAdminRoleLinkType < BaseObject
      graphql_name 'LdapAdminRoleLink'
      description 'Represents an instance-level LDAP link.'

      field :id, GraphQL::Types::ID,
        null: false, description: 'ID of the LDAP link.'

      field :admin_member_role, ::Types::Members::AdminMemberRoleType,
        null: false, description: 'Custom admin member role.', method: :member_role

      field :provider, GraphQL::Types::String,
        null: false, description: 'LDAP provider for the LDAP link.'

      field :cn, GraphQL::Types::String,
        null: true, description: 'Common Name (CN) of the LDAP group.'

      field :filter, GraphQL::Types::String,
        null: true, description: 'Search filter for the LDAP group.'
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
