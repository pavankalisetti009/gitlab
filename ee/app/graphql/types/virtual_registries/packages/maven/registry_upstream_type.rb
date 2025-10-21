# frozen_string_literal: true

module Types
  module VirtualRegistries
    module Packages
      module Maven
        # rubocop: disable Graphql/AuthorizeTypes -- authorization handled by parent UpstreamType
        class RegistryUpstreamType < ::Types::BaseObject
          graphql_name 'MavenRegistryUpstream'
          description 'Represents the upstream registries of a Maven virtual registry.'

          field :id, GraphQL::Types::ID, null: false,
            description: 'ID of the registry upstream.',
            experiment: { milestone: '18.2' }

          field :position, GraphQL::Types::Int, null: false,
            description: 'Position of the upstream registry in an ordered list.',
            experiment: { milestone: '18.2' }
        end
        # rubocop: enable Graphql/AuthorizeTypes
      end
    end
  end
end
