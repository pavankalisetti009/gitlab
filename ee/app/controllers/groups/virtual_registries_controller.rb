# frozen_string_literal: true

module Groups
  class VirtualRegistriesController < Groups::ApplicationController
    before_action :ensure_feature!
    before_action :verify_read_virtual_registry!, only: [:index]

    feature_category :virtual_registry
    urgency :low

    private

    def ensure_feature!
      render_404 unless @group.root?
      render_404 unless ::Feature.enabled?(:virtual_registry_maven, @group)
      render_404 unless ::Feature.enabled?(:ui_for_virtual_registries, @group)
      render_404 unless ::Gitlab.config.dependency_proxy.enabled
      render_404 unless @group.licensed_feature_available?(:packages_virtual_registry)
    end

    def verify_read_virtual_registry!
      access_denied! unless can?(current_user, :read_virtual_registry, @group.virtual_registry_policy_subject)
    end
  end
end
