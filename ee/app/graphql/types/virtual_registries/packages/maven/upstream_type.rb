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

          implements Types::VirtualRegistries::UpstreamInterface

          field :metadata_cache_validity_hours, GraphQL::Types::Int, null: false,
            description: 'Time before the cache expires for Maven metadata.',
            experiment: { milestone: '18.4' }

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
