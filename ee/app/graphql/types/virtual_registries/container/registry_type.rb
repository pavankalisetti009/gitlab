# frozen_string_literal: true

module Types
  module VirtualRegistries
    module Container
      class RegistryType < ::Types::BaseObject
        graphql_name 'ContainerRegistry'
        description 'Represents a container virtual registry'

        authorize :read_virtual_registry

        implements Types::VirtualRegistries::RegistryInterface

        alias_method :registry, :object
      end
    end
  end
end
