# frozen_string_literal: true

module Types
  module VirtualRegistries
    module Container
      class RegistryUpstreamWithUpstreamType < ::Types::BaseObject
        graphql_name 'ContainerRegistryUpstreamWithUpstream'
        description 'Represents a container virtual registry upstream and its relationship to the upstream.'

        authorize :read_virtual_registry

        field :id, GraphQL::Types::ID, null: false,
          description: 'ID of the registry upstream.',
          experiment: { milestone: '18.7' }

        field :position, GraphQL::Types::Int, null: false,
          description: 'Position of the upstream registry in an ordered list.',
          experiment: { milestone: '18.7' }

        field :upstream, ::Types::VirtualRegistries::Container::UpstreamType, null: false,
          description: 'Container upstream associated with the registry upstream.',
          experiment: { milestone: '18.7' }

        def upstream
          Gitlab::Graphql::Loaders::BatchModelLoader.new(
            ::VirtualRegistries::Container::Upstream,
            object.upstream_id
          ).find
        end
      end
    end
  end
end
