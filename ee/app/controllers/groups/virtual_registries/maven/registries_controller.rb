# frozen_string_literal: true

module Groups
  module VirtualRegistries
    module Maven
      class RegistriesController < Groups::VirtualRegistries::BaseController
        before_action :verify_read_virtual_registry!, only: [:index]
        before_action :verify_create_virtual_registry!, only: [:new]

        before_action :push_ability, only: [:index]

        feature_category :virtual_registry
        urgency :low

        def index; end

        def new; end

        private

        def push_ability
          push_frontend_ability(ability: :update_virtual_registry,
            resource: group.virtual_registry_policy_subject, user: current_user)
        end
      end
    end
  end
end
