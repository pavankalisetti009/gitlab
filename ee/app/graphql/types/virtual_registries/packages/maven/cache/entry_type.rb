# frozen_string_literal: true

module Types
  module VirtualRegistries
    module Packages
      module Maven
        module Cache
          # rubocop: disable Graphql/AuthorizeTypes -- authorization handled by parent UpstreamType
          class EntryType < ::Types::BaseObject
            graphql_name 'MavenUpstreamCacheEntry'
            description 'Represents a cache entry for a Maven upstream.'

            connection_type_class ::Types::CountableConnectionType

            field :id, # rubocop: disable GraphQL/FieldMethod -- Do not wrap the result with a global ID
              GraphQL::Types::String, null: false,
              description: 'ID of the cache entry.',
              experiment: { milestone: '18.7' }

            field :relative_path, GraphQL::Types::String, null: false,
              description: 'Relative path of the cached entry.',
              experiment: { milestone: '18.7' }

            field :size, GraphQL::Types::BigInt, null: false,
              description: 'Size of the cached file in bytes.',
              experiment: { milestone: '18.7' }

            field :content_type, GraphQL::Types::String, null: false,
              description: 'Content type of the cached file.',
              experiment: { milestone: '18.7' }

            # rubocop: disable GraphQL/ExtractType -- no value for now
            field :file_md5, GraphQL::Types::String, null: true,
              description: 'MD5 hash of the cached file.',
              experiment: { milestone: '18.7' }

            field :file_sha1, GraphQL::Types::String, null: false,
              description: 'SHA1 hash of the cached file.',
              experiment: { milestone: '18.7' }

            field :upstream_etag, GraphQL::Types::String, null: true,
              description: 'ETag from the upstream source.',
              experiment: { milestone: '18.7' }

            field :upstream_checked_at, Types::TimeType, null: true,
              description: 'Timestamp when the upstream was last checked.',
              experiment: { milestone: '18.7' }
            # rubocop: enable GraphQL/ExtractType

            field :downloads_count, GraphQL::Types::Int, null: false,
              description: 'Number of times the entry has been downloaded.',
              experiment: { milestone: '18.7' }

            field :created_at, Types::TimeType, null: false,
              description: 'Timestamp when the cache entry was created.',
              experiment: { milestone: '18.7' }

            field :updated_at, Types::TimeType, null: false,
              description: 'Timestamp when the cache entry was last updated.',
              experiment: { milestone: '18.7' }

            field :downloaded_at, Types::TimeType, null: true,
              description: 'Timestamp when the cache entry was last downloaded.',
              experiment: { milestone: '18.7' }

            def id
              object.generate_id
            end
          end
          # rubocop: enable Graphql/AuthorizeTypes
        end
      end
    end
  end
end
