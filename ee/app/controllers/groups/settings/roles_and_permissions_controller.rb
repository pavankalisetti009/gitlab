# frozen_string_literal: true

module Groups
  module Settings
    class RolesAndPermissionsController < Groups::ApplicationController
      include ::GitlabSubscriptions::SubscriptionHelper
      include ::EE::RolesAndPermissions # rubocop: disable Cop/InjectEnterpriseEditionModule -- EE-only concern

      feature_category :user_management

      before_action :authorize_admin_member_roles!, except: [:index, :show]
      before_action :authorize_view_member_roles!, only: [:index, :show]
      before_action :ensure_root_group!
      before_action :ensure_gitlab_com_subscription!

      private

      def authorize_admin_member_roles!
        render_404 unless can?(current_user, :admin_member_role, group)
      end

      def authorize_view_member_roles!
        render_404 unless can?(current_user, :view_member_roles, group)
      end

      def ensure_root_group!
        render_404 unless group.root?
      end

      def ensure_gitlab_com_subscription!
        render_404 unless gitlab_com_subscription?
      end
    end
  end
end
