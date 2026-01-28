# frozen_string_literal: true

module Groups
  module Settings
    class ServiceAccountsController < Groups::ApplicationController
      include ::GitlabSubscriptions::SubscriptionHelper

      feature_category :user_management

      before_action :ensure_root_group!

      before_action :authorize_admin_service_accounts!, except: [:index, :show]
      before_action :authorize_read_service_accounts!, only: [:index, :show]

      before_action do
        push_frontend_feature_flag(:edit_service_account_email, group)
      end

      private

      def ensure_root_group!
        return if ::Feature.enabled?(:allow_subgroups_to_create_service_accounts, group.root_ancestor)

        return if group.root?

        render_404
      end

      def authorize_read_service_accounts!
        render_404 unless can?(current_user, :read_service_account, group)
      end

      def authorize_admin_service_accounts!
        render_404 unless can?(current_user, :create_service_account, group) &&
          can?(current_user, :delete_service_account, group)
      end
    end
  end
end
