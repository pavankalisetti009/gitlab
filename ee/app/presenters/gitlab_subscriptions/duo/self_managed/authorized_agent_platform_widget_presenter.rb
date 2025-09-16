# frozen_string_literal: true

module GitlabSubscriptions
  module Duo
    module SelfManaged
      class AuthorizedAgentPlatformWidgetPresenter < Duo::BaseAgentPlatformWidgetPresenter
        include GitlabSubscriptions::Duo::SelfManaged::WidgetCommon

        private

        def contextual_attributes
          {
            isAuthorized: true,
            featurePreviewAttribute: :instance_level_ai_beta_features_enabled,
            requestCount: ::Ai::Setting.instance.duo_agent_platform_request_count,
            requestText: s_(
              'DuoAgentPlatform|The number of users in your instance who have requested access to GitLab Duo Core.'
            )
          }
        end

        def action_path
          ::Gitlab::Routing.url_helpers.update_duo_agent_platform_admin_application_settings_path
        end
      end
    end
  end
end
