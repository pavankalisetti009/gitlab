# frozen_string_literal: true

module Types
  module VirtualRegistries
    module Packages
      module Maven
        # rubocop: disable Graphql/AuthorizeTypes -- authorization handled by parent RegistryType
        class RegistryDetailsType < ::Types::VirtualRegistries::Packages::Maven::RegistryType
          graphql_name 'MavenRegistryDetails'
          description 'Represents Maven virtual registry details'

          field :registry_upstreams,
            [::Types::VirtualRegistries::Packages::Maven::RegistryUpstreamWithUpstreamType],
            null: false,
            description: 'List of registry upstreams for the Maven virtual registry.',
            experiment: { milestone: '18.7' }

          # This field will be removed once frontend
          # is updated to use `registry_upstreams`
          # https://gitlab.com/gitlab-org/gitlab/-/issues/581475
          field :upstreams,
            [::Types::VirtualRegistries::Packages::Maven::UpstreamDetailsType],
            null: true,
            description: 'List of upstream registries for the Maven virtual registry.',
            experiment: { milestone: '18.1' }

          def upstreams
            ::VirtualRegistries::Packages::Maven::Upstream.eager_load_registry_upstream(registry: registry)
          end
        end
        # rubocop: enable Graphql/AuthorizeTypes
      end
    end
  end
end
