# frozen_string_literal: true

module Types
  module VirtualRegistries
    module Packages
      module Maven
        # rubocop: disable Graphql/AuthorizeTypes -- authorization handled by parent UpstreamType
        class UpstreamDetailsType < ::Types::VirtualRegistries::Packages::Maven::UpstreamType
          graphql_name 'MavenUpstreamDetails'
          description 'Represents Maven upstream registry details.'

          field :registry_upstreams,
            [::Types::VirtualRegistries::Packages::Maven::RegistryUpstreamWithRegistryType],
            null: false,
            description: 'Represents the upstream registry for the upstream ' \
              'which contains the position data.',
            experiment: { milestone: '18.2' }
        end
        # rubocop: enable Graphql/AuthorizeTypes
      end
    end
  end
end
