# frozen_string_literal: true

module GitlabSubscriptions
  module Duo
    module GitlabCom
      class AgentPlatformWidgetPresenter < Duo::BaseAgentPlatformWidgetPresenter
        include GitlabSubscriptions::Duo::GitlabCom::WidgetCommon

        def initialize(user, namespace)
          super(user)

          @namespace = namespace
        end

        private

        attr_reader :namespace

        def contextual_attributes
          {
            isAuthorized: false,
            showRequestAccess: requestable?,
            hasRequested: user_has_requested?,
            requestText: s_('DuoAgentPlatform|Request has been sent to the group Owner')
          }
        end

        def requestable?
          GitlabSubscriptions::Duo.requestable?(namespace)
        end

        def action_path
          ::Gitlab::Routing.url_helpers.request_duo_agent_platform_group_callouts_path(namespace_id: namespace.id)
        end

        def user_has_requested?
          user.dismissed_callout_for_group?(feature_name: 'duo_agent_platform_requested', group: namespace)
        end
      end
    end
  end
end
