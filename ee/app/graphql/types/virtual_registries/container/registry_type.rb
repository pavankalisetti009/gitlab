# frozen_string_literal: true

module Types
  module VirtualRegistries
    module Container
      class RegistryType < ::Types::BaseObject
        graphql_name 'ContainerRegistry'
        description 'Represents a container virtual registry'

        authorize :read_virtual_registry

        alias_method :registry, :object

        field :id, GraphQL::Types::ID, null: false,
          description: 'ID of the virtual registry.'

        field :name, GraphQL::Types::String, null: false,
          description: 'Name of the virtual registry.'

        field :description, GraphQL::Types::String, null: true,
          description: 'Description of the virtual registry.'

        field :updated_at, ::Types::TimeType, null: false,
          description: 'Timestamp of when the virtual registry was updated.'
      end
    end
  end
end
