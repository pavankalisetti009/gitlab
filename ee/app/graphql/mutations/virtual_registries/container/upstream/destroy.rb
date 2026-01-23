# frozen_string_literal: true

module Mutations
  module VirtualRegistries
    module Container
      module Upstream
        class Destroy < ::Mutations::VirtualRegistries::Upstream::Destroy
          graphql_name 'ContainerUpstreamDelete'

          argument :id, ::Types::GlobalIDType[::VirtualRegistries::Container::Upstream],
            required: true,
            description: 'ID of the upstream to be deleted.'

          field :upstream,
            ::Types::VirtualRegistries::Container::UpstreamDetailsType,
            null: true,
            description: 'Destroyed upstream.'

          private

          def service_class
            ::VirtualRegistries::Container::DestroyUpstreamService
          end
        end
      end
    end
  end
end
