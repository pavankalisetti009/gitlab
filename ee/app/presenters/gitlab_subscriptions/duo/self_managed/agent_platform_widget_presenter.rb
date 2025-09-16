# frozen_string_literal: true

module GitlabSubscriptions
  module Duo
    module SelfManaged
      class AgentPlatformWidgetPresenter < Duo::BaseAgentPlatformWidgetPresenter
        include GitlabSubscriptions::Duo::SelfManaged::WidgetCommon

        private

        def user_has_requested?
          user.dismissed_callout?(feature_name: 'duo_agent_platform_requested')
        end

        def contextual_attributes
          {
            isAuthorized: false,
            showRequestAccess: requestable?,
            hasRequested: user_has_requested?,
            requestText: s_('DuoAgentPlatform|Request has been sent to the instance Admin')
          }
        end

        def requestable?
          GitlabSubscriptions::Duo.self_managed_requestable?
        end

        def action_path
          ::Gitlab::Routing.url_helpers.request_duo_agent_platform_callouts_path
        end
      end
    end
  end
end
