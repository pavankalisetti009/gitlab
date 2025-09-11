# frozen_string_literal: true

module GitlabSubscriptions
  module Duo
    module SelfManaged
      class AuthorizedAgentPlatformWidgetPresenter < Duo::BaseAgentPlatformWidgetPresenter
        include GitlabSubscriptions::Duo::SelfManaged::WidgetCommon

        private

        def user_attributes
          { isAuthorized: true, showRequestAccess: false, requestCount: current_request_count }
        end

        def action_path
          ::Gitlab::Routing.url_helpers.update_duo_agent_platform_admin_application_settings_path
        end
      end
    end
  end
end
