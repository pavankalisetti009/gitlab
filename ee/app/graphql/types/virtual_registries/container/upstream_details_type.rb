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
          description: 'Represents the connected upstream registry for an upstream ' \
            'and the upstream position data.',
          experiment: { milestone: '18.8' }
      end
    end
  end
end
