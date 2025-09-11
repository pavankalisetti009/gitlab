# frozen_string_literal: true

module GitlabSubscriptions
  module Duo
    module SelfManaged
      class AuthorizedAgentPlatformWidgetPresenter < Duo::BaseAgentPlatformWidgetPresenter
        include GitlabSubscriptions::Duo::SelfManaged::WidgetCommon
        extend ::Gitlab::Utils::Override

        private

        def user_attributes
          { isAuthorized: true, showRequestAccess: false, requestCount: current_request_count }
        end

        def action_path
          ::Gitlab::Routing.url_helpers.update_duo_agent_platform_admin_application_settings_path
        end

        override :feature_preview_attribute
        def feature_preview_attribute
          :instance_level_ai_beta_features_enabled
        end
      end
    end
  end
end
