# frozen_string_literal: true

module Types
  module VirtualRegistries
    module Container
      class UpstreamDetailsType < ::Types::VirtualRegistries::Container::UpstreamType
        graphql_name 'ContainerUpstreamDetails'
        description 'Represents container upstream details.'
        authorize :read_virtual_registry
        field :registry_upstreams,
          [::Types::VirtualRegistries::Container::RegistryUpstreamWithRegistryType],
          null: false,
          description: 'Shows the connected registry for the upstream, and its list position.',
          experiment: { milestone: '18.8' }
      end
    end
  end
end
