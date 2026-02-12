# frozen_string_literal: true

module Projects
  module Settings
    class ServiceAccountsController < Projects::ApplicationController
      include ::GitlabSubscriptions::SubscriptionHelper

      feature_category :user_management

      before_action :check_feature_flag!
      before_action :authorize_admin_service_accounts!, except: [:index, :show]
      before_action :authorize_read_service_accounts!, only: [:index, :show]

      before_action do
        push_frontend_feature_flag(:edit_service_account_email, project)
      end

      private

      def check_feature_flag!
        render_404 unless ::Feature.enabled?(:allow_projects_to_create_service_accounts, project.root_ancestor)
      end

      def authorize_read_service_accounts!
        render_404 unless can?(current_user, :read_service_account, project)
      end

      def authorize_admin_service_accounts!
        render_404 unless can?(current_user, :create_service_account, project) &&
          can?(current_user, :delete_service_account, project)
      end
    end
  end
end
