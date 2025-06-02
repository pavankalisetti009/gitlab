# frozen_string_literal: true

# rubocop: disable Gitlab/EeOnlyClass -- EE only class with no CE equivalent
module EE
  module Types
    module VirtualRegistries
      module Packages
        module Maven
          class MavenVirtualRegistryType < ::Types::BaseObject
            graphql_name 'MavenVirtualRegistry'
            description 'Represents a Maven virtual registry'

            authorize :read_virtual_registry

            field :id, GraphQL::Types::ID, null: false,
              description: 'ID of the virtual registry.'

            field :name, GraphQL::Types::String, null: false,
              description: 'Name of the virtual registry.'

            field :description, GraphQL::Types::String, null: true,
              description: 'Description of the virtual registry.'
          end
        end
      end
    end
  end
end
# rubocop: enable Gitlab/EeOnlyClass
