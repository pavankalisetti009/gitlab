# frozen_string_literal: true

module Types
  module VirtualRegistries
    module Container
      class UpstreamType < ::Types::BaseObject
        graphql_name 'ContainerUpstream'
        description 'Represents a container upstream registry.'

        authorize :read_virtual_registry
        connection_type_class ::Types::CountableConnectionType

        field :id, GraphQL::Types::ID, null: false,
          description: 'ID of the upstream registry.',
          experiment: { milestone: '18.7' }

        field :url, GraphQL::Types::String, null: false,
          description: 'URL of the upstream registry.',
          experiment: { milestone: '18.7' }

        field :cache_validity_hours, GraphQL::Types::Int, null: false,
          description: 'Time before the cache expires for the upstream registry.',
          experiment: { milestone: '18.7' }

        field :username, GraphQL::Types::String, null: true,
          description: 'Username to sign in to the upstream registry.',
          experiment: { milestone: '18.7' }

        field :name, GraphQL::Types::String, null: false,
          description: 'Name of the upstream registry.',
          experiment: { milestone: '18.7' }

        field :description, GraphQL::Types::String, null: true,
          description: 'Description of the upstream registry.',
          experiment: { milestone: '18.7' }

        field :registries_count, GraphQL::Types::Int,
          null: false,
          experiment: { milestone: '18.7' },
          description: 'Number of registries using the upstream.'

        def registries_count
          BatchLoader::GraphQL.for(object.id)
            .batch(key: 'vregs-container-upstreams-registries-count') do |upstream_ids, loader|
            counts = ::VirtualRegistries::Container::RegistryUpstream
              .registries_count_by_upstream_ids(upstream_ids)

            upstream_ids.each { |id| loader.call(id, counts[id] || 0) }
          end
        end
      end
    end
  end
end
