# frozen_string_literal: true

module Mutations
  module VirtualRegistries
    module Registry
      # rubocop:disable GraphQL/GraphqlName -- This is a base mutation so name is not needed here
      class Update < BaseMutation
        authorize :update_virtual_registry

        argument :id, ::GraphQL::Types::ID,
          required: true,
          description: 'ID of the virtual registry.'

        argument :name, ::GraphQL::Types::String,
          required: true,
          description: 'Name of virtual registry.'

        argument :description, ::GraphQL::Types::String,
          required: false,
          description: 'Description of the virtual registry.'

        def resolve(id:, **args)
          registry = authorized_find!(id: id)

          result = service_class.new(registry: registry, current_user: current_user, params: args).execute

          raise_resource_not_available_error! if result.reason == :unavailable

          if result.status == :success
            {
              registry: result.payload,
              errors: []
            }
          else
            {
              registry: nil,
              errors: result.message
            }
          end
        end

        private

        def authorize!(registry)
          return if authorized_resource?(registry.group.virtual_registry_policy_subject)

          raise_resource_not_available_error!
        end
      end
      # rubocop:enable GraphQL/GraphqlName
    end
  end
end
