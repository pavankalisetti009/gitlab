# frozen_string_literal: true

module Admin
  module GitlabDuo
    module Usage
      class UsersController < Admin::ApplicationController
        feature_category :consumables_cost_management
        urgency :low

        before_action :ensure_feature_available!

        def show
          @username = params.permit(:username)[:username]
        end

        private

        def ensure_feature_available!
          return render_404 unless Feature.enabled?(:usage_billing_dev, :instance)
          return render_404 unless License.feature_available?(:usage_billing)

          render_404 if Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
        end
      end
    end
  end
end
