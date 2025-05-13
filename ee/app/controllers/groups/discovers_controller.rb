# frozen_string_literal: true

module Groups
  class DiscoversController < Groups::ApplicationController
    before_action :authorize_admin_group!
    before_action :authorize_discover_page

    feature_category :activation
    urgency :low

    def show
      if Feature.enabled?(:reveal_duo_core_feature, @group)
        render GitlabSubscriptions::DiscoverDuoCoreTrialComponent.new(namespace: @group)
      else
        render GitlabSubscriptions::DiscoverTrialComponent.new(namespace: @group)
      end
    end

    private

    def authorize_discover_page
      render_404 unless ::Gitlab::Saas.feature_available?(:subscriptions_trials)
    end
  end
end
