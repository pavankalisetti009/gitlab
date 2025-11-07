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
            [::Types::VirtualRegistries::Packages::Maven::RegistryUpstreamType],
            null: false,
            description: 'Represents the upstream registry for the upstream ' \
              'which contains the position data.',
            experiment: { milestone: '18.2' }

          field :registries,
            ::Types::VirtualRegistries::Packages::Maven::RegistryType.connection_type,
            null: false,
            description: 'Represents the virtual registries which use the upstream.',
            experiment: { milestone: '18.4' }
        end
        # rubocop: enable Graphql/AuthorizeTypes
      end
    end
  end
end
