# frozen_string_literal: true

module Types
  module VirtualRegistries
    module Packages
      module Maven
        class UpstreamType < ::Types::BaseObject
          graphql_name 'MavenUpstream'
          description 'Represents a Maven upstream registry.'

          authorize :read_virtual_registry
          connection_type_class ::Types::CountableConnectionType

          field :id, GraphQL::Types::ID, null: false,
            description: 'ID of the upstream registry.',
            experiment: { milestone: '18.1' }

          field :url, GraphQL::Types::String, null: false,
            description: 'URL of the upstream registry.',
            experiment: { milestone: '18.1' }

          field :cache_validity_hours, GraphQL::Types::Int, null: false,
            description: 'Time before the cache expires for the upstream registry.',
            experiment: { milestone: '18.1' }

          field :metadata_cache_validity_hours, GraphQL::Types::Int, null: false,
            description: 'Time before the cache expires for Maven metadata.',
            experiment: { milestone: '18.4' }

          field :username, GraphQL::Types::String, null: true,
            description: 'Username to sign in to the upstream registry.',
            experiment: { milestone: '18.1' }

          field :name, GraphQL::Types::String, null: false,
            description: 'Name of the upstream registry.',
            experiment: { milestone: '18.1' }

          field :description, GraphQL::Types::String, null: true,
            description: 'Description of the upstream registry.',
            experiment: { milestone: '18.1' }

          field :registries_count, GraphQL::Types::Int,
            null: false,
            experiment: { milestone: '18.6' },
            description: 'Number of registries using the upstream.'

          field :registries,
            ::Types::VirtualRegistries::Packages::Maven::RegistryType.connection_type,
            null: false,
            description: 'Represents the virtual registries which use the upstream.',
            experiment: { milestone: '18.4' }

          field :registry_upstreams,
            [::Types::VirtualRegistries::Packages::Maven::RegistryUpstreamType],
            null: false,
            description: 'Represents the upstream registry for the upstream ' \
              'which contains the position data.',
            experiment: { milestone: '18.2' }

          def registries_count
            BatchLoader::GraphQL.for(object.id)
              .batch(key: 'vregs-maven-upstreams-registries-count') do |upstream_ids, loader|
              counts = ::VirtualRegistries::Packages::Maven::RegistryUpstream
                .registries_count_by_upstream_ids(upstream_ids)

              upstream_ids.each { |id| loader.call(id, counts[id] || 0) }
            end
          end
        end
      end
    end
  end
end
