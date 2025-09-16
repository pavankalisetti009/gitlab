# frozen_string_literal: true

module GitlabSubscriptions
  module Duo
    module GitlabCom
      class AuthorizedAgentPlatformWidgetPresenter < Duo::BaseAgentPlatformWidgetPresenter
        include GrapePathHelpers::NamedRouteMatcher
        include GitlabSubscriptions::Duo::GitlabCom::WidgetCommon
        extend ::Gitlab::Utils::Override

        def initialize(user, namespace)
          super(user)

          @namespace = namespace
        end

        private

        attr_reader :namespace

        def action_path
          api_v4_groups_path(id: namespace.id)
        end

        def contextual_attributes
          {
            isAuthorized: true,
            featurePreviewAttribute: :experiment_features_enabled,
            requestCount: namespace.duo_agent_platform_request_count,
            requestText: s_(
              'DuoAgentPlatform|The number of users in your group who have requested access to GitLab Duo Core.'
            )
          }
        end
      end
    end
  end
end
