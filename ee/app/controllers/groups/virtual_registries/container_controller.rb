# frozen_string_literal: true

module Groups
  module VirtualRegistries
    class ContainerController < Groups::ApplicationController
      before_action :ensure_feature!, only: [:index]
      before_action :push_update_ability, only: [:index]

      feature_category :virtual_registry
      urgency :low

      def index; end

      private

      def push_update_ability
        push_frontend_ability(ability: :update_virtual_registry,
          resource: group.virtual_registry_policy_subject, user: current_user)
      end

      def ensure_feature!
        render_404 unless ::Feature.enabled?(:ui_for_container_virtual_registries, group)
        render_404 unless ::VirtualRegistries::Container.virtual_registry_available?(group, current_user)
      end
    end
  end
end
