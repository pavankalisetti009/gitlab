# frozen_string_literal: true

module Groups
  module Settings
    module GitlabDuo
      class ConfigurationController < Groups::ApplicationController
        feature_category :ai_abstraction_layer

        include ::Nav::GitlabDuoSettingsPage

        before_action do
          push_frontend_feature_flag(:group_duo_page_configuration_settings, group)
        end

        def index
          redirect_to group_settings_gitlab_duo_path(group) unless render_configuration_page?
        end

        private

        def render_configuration_page?
          Feature.enabled?(:group_duo_page_configuration_settings, group) &&
            show_gitlab_duo_settings_menu_item?(group)
        end
      end
    end
  end
end
