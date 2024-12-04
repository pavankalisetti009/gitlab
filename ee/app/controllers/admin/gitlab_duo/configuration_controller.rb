# frozen_string_literal: true

# EE:Self Managed
module Admin
  module GitlabDuo
    class ConfigurationController < Admin::ApplicationController
      include ::GitlabSubscriptions::CodeSuggestionsHelper
      include ::Admin::ApplicationSettingsHelper

      before_action :ensure_feature_available!

      respond_to :html

      feature_category :ai_abstraction_layer
      urgency :low

      before_action do
        push_frontend_feature_flag(:admin_duo_page_configuration_settings)
      end

      def index; end

      private

      def ensure_feature_available!
        return if !Gitlab.org_or_com? && # rubocop:disable Gitlab/AvoidGitlabInstanceChecks -- Not related to SaaS offerings
          admin_display_duo_addon_settings? &&
          License.current.present? &&
          License.current.paid? &&
          Feature.enabled?(:admin_duo_page_configuration_settings, :instance)

        redirect_to admin_gitlab_duo_path
      end
    end
  end
end
