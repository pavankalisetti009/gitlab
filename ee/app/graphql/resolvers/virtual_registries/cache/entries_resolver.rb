# frozen_string_literal: true

module Resolvers
  module VirtualRegistries
    module Cache
      # rubocop:disable Graphql/ResolverType -- the type is inherited from the parent class
      class EntriesResolver < BaseResolver
        alias_method :upstream, :object

        argument :search, GraphQL::Types::String,
          required: false,
          default_value: nil,
          description: 'Search cache entries by relative path.'

        def resolve(**args)
          return unless virtual_registry_available?

          ::VirtualRegistries::Cache::EntriesFinder.new(
            upstream: upstream,
            params: args.slice(:search)
          ).execute
        end

        private

        def authorized?(**_args)
          Ability.allowed?(current_user, :read_virtual_registry, upstream)
        end

        def virtual_registry_available?
          raise NotImplementedError, "#{self} does not implement #{__method__}"
        end
      end
      # rubocop:enable Graphql/ResolverType
    end
  end
end
