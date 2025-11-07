# frozen_string_literal: true

module Resolvers
  module VirtualRegistries
    module Packages
      module Maven
        class UpstreamsResolver < BaseResolver
          type ::Types::VirtualRegistries::Packages::Maven::UpstreamType.connection_type, null: true

          argument :upstream_name, GraphQL::Types::String,
            required: false,
            default_value: nil,
            description: 'Search upstreams by name.'

          def resolve(**args)
            return unless ::VirtualRegistries::Packages::Maven.virtual_registry_available?(object, current_user)

            ::VirtualRegistries::UpstreamsFinder.new(
              upstream_class: ::VirtualRegistries::Packages::Maven::Upstream,
              group: object,
              params: args.slice(:upstream_name)
            ).execute
          end
        end
      end
    end
  end
end
