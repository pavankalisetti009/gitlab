# frozen_string_literal: true

module Types
  module VirtualRegistries
    module Packages
      module Maven
        # rubocop: disable Graphql/AuthorizeTypes -- authorization handled by parent UpstreamType
        class RegistryUpstreamWithRegistryType < ::Types::VirtualRegistries::Packages::Maven::RegistryUpstreamType
          graphql_name 'MavenRegistryUpstreamWithRegistry'
          description 'Represents a Maven virtual registry upstream and its relationship to the registry.'

          field :registry, ::Types::VirtualRegistries::Packages::Maven::RegistryType, null: false,
            description: 'Maven registry associated with the registry upstream.',
            experiment: { milestone: '18.6' }

          def registry
            Gitlab::Graphql::Loaders::BatchModelLoader.new(
              ::VirtualRegistries::Packages::Maven::Registry,
              object.registry_id
            ).find
          end
        end
        # rubocop: enable Graphql/AuthorizeTypes
      end
    end
  end
end
