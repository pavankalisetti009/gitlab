# frozen_string_literal: true

module VirtualRegistries
  module Container
    class CreateRegistryService < ::BaseContainerService
      alias_method :group, :container

      def initialize(group:, current_user: nil, params: {})
        super(container: group, current_user: current_user, params: params)
      end

      def execute
        unless ::VirtualRegistries::Container.virtual_registry_available?(group, current_user)
          return ServiceResponse.error(message: _('Container virtual registry not available'), reason: :unavailable)
        end

        registry = ::VirtualRegistries::Container::Registry.build(params.merge(group: group))

        if registry.save
          ServiceResponse.success(payload: registry)
        else
          ServiceResponse.error(message: registry.errors.full_messages)
        end
      end
    end
  end
end
