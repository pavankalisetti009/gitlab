# frozen_string_literal: true

module Admin
  module ApplicationSettings
    class RolesAndPermissionsController < Admin::ApplicationController
      include ::GitlabSubscriptions::SubscriptionHelper
      include ::EE::RolesAndPermissions # rubocop: disable Cop/InjectEnterpriseEditionModule -- EE-only concern

      feature_category :user_management

      before_action :ensure_custom_roles_available!

      private

      def ensure_custom_roles_available!
        render_404 if gitlab_com_subscription? || !License.feature_available?(:custom_roles)
      end
    end
  end
end
