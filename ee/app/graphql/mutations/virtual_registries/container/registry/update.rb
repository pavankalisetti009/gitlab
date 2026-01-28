# frozen_string_literal: true

module Mutations
  module VirtualRegistries
    module Container
      module Registry
        class Update < ::Mutations::VirtualRegistries::Registry::Update
          graphql_name 'ContainerVirtualRegistryUpdate'

          argument :id, ::Types::GlobalIDType[::VirtualRegistries::Container::Registry],
            required: true,
            description: 'ID of the container virtual registry to be updated.'

          field :registry,
            ::Types::VirtualRegistries::Container::RegistryType,
            null: true,
            description: 'Container virtual registry after the mutation.'

          private

          def service_class
            ::VirtualRegistries::Container::UpdateRegistryService
          end
        end
      end
    end
  end
end
