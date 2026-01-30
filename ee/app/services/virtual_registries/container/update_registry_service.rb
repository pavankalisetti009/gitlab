# frozen_string_literal: true

module VirtualRegistries
  module Container
    class UpdateRegistryService
      ALLOWED_PARAMS = [:name, :description].freeze

      attr_reader :registry, :current_user, :params

      def initialize(registry:, current_user: nil, params: {})
        @registry = registry
        @current_user = current_user
        @params = params
      end

      def execute
        unless ::VirtualRegistries::Container.virtual_registry_available?(registry.group, current_user)
          return ServiceResponse.error(
            message: s_('VirtualRegistry|Container virtual registry not available'), reason: :unavailable
          )
        end

        if registry.update(params.slice(*ALLOWED_PARAMS))
          ServiceResponse.success(payload: registry)
        else
          ServiceResponse.error(message: registry.errors.full_messages)
        end
      end
    end
  end
end
