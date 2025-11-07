# frozen_string_literal: true

module Mutations
  module VirtualRegistries
    module Packages
      module Maven
        class MavenUpstreamCreateMutation < BaseMutation
          graphql_name 'MavenUpstreamCreate'

          authorize :create_virtual_registry

          argument :id, ::Types::GlobalIDType[::VirtualRegistries::Packages::Maven::Registry],
            required: true,
            description: 'ID of the upstream registry.'

          argument :name, GraphQL::Types::String,
            required: true,
            description: 'Name of upstream registry.'

          argument :description, GraphQL::Types::String,
            required: false,
            description: 'Description of the upstream registry.'

          argument :url, GraphQL::Types::String,
            required: true,
            description: 'URL of the upstream registry.'

          argument :cache_validity_hours, GraphQL::Types::Int,
            required: false,
            default_value: 24,
            description: 'Cache validity period. Defaults to 24 hours.'

          argument :metadata_cache_validity_hours, GraphQL::Types::Int,
            required: false,
            default_value: 24,
            experiment: { milestone: '18.4' },
            description: 'Metadata cache validity period. Defaults to 24 hours.'

          argument :username, GraphQL::Types::String,
            required: false,
            description: 'Username of the upstream registry.'

          argument :password, GraphQL::Types::String,
            required: false,
            description: 'Password of the upstream registry.'

          field :upstream,
            ::Types::VirtualRegistries::Packages::Maven::UpstreamDetailsType,
            null: true,
            description: 'Maven upstream after the mutation.'

          def resolve(id:, **args)
            registry = authorized_find!(id: id)

            raise_resource_not_available_error! if registry.nil?

            raise_resource_not_available_error! unless ::VirtualRegistries::Packages::Maven.virtual_registry_available?(
              registry.group, current_user)

            service_response = ::VirtualRegistries::Packages::Maven::CreateUpstreamService
                                 .new(registry: registry, current_user: current_user, params: args)
                                 .execute

            {
              upstream: service_response.success? ? service_response.payload : nil,
              errors: service_response.errors
            }
          end
        end
      end
    end
  end
end
