# frozen_string_literal: true

# EE:Self Managed
module Admin
  module GitlabDuo
    class SeatUtilizationController < Admin::ApplicationController
      include ::GitlabSubscriptions::CodeSuggestionsHelper

      respond_to :html

      feature_category :seat_cost_management
      urgency :low

      before_action :ensure_feature_available!

      before_action do
        push_frontend_feature_flag(:enable_add_on_users_filtering)
        push_frontend_feature_flag(:enable_add_on_users_pagesize_selection)
      end

      def index
        @subscription_name = License.current.subscription_name
        duo_purchase = GitlabSubscriptions::AddOnPurchase.for_self_managed.for_duo_pro_or_duo_enterprise.last

        @duo_add_on_start_date = duo_purchase&.started_at
        @duo_add_on_end_date = duo_purchase&.expires_on
      end

      private

      def ensure_feature_available!
        render_404 unless !gitlab_com_subscription? && License.current&.paid?
      end
    end
  end
end
