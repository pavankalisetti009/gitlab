# frozen_string_literal: true

module Types
  module VirtualRegistries
    module Container
      module Cache
        # rubocop: disable Graphql/AuthorizeTypes -- authorization handled by parent UpstreamType
        class EntryType < ::Types::BaseObject
          graphql_name 'ContainerUpstreamCacheEntry'
          description 'Represents a cache entry for an upstream container registry.'

          implements Types::VirtualRegistries::Cache::EntryInterface
        end
        # rubocop: enable Graphql/AuthorizeTypes
      end
    end
  end
end
