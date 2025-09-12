# frozen_string_literal: true

module GitlabSubscriptions
  module Duo
    module GitlabCom
      class AuthorizedAgentPlatformWidgetPresenter < Duo::BaseAgentPlatformWidgetPresenter
        include GrapePathHelpers::NamedRouteMatcher
        extend ::Gitlab::Utils::Override

        def initialize(user, namespace)
          super(user)

          @namespace = namespace
        end

        private

        attr_reader :namespace

        def eligible?
          ::Feature.enabled?(:duo_agent_platform_widget_gitlab_com, namespace) &&
            !namespace.trial? &&
            namespace.licensed_duo_core_features_available?
        end

        def enabled_without_beta_features?
          GitlabSubscriptions::Duo.enabled_without_beta_features?(namespace)
        end

        def fully_enabled?
          GitlabSubscriptions::Duo.agent_fully_enabled?(namespace)
        end

        def only_duo_default_off?
          GitlabSubscriptions::Duo.only_duo_default_off?(namespace)
        end

        def enabled_without_core?
          GitlabSubscriptions::Duo.enabled_without_core?(namespace)
        end

        def action_path
          api_v4_groups_path(id: namespace.id)
        end

        def contextual_attributes
          {
            isAuthorized: true,
            featurePreviewAttribute: :experiment_features_enabled,
            requestCount: 0
          }
        end
      end
    end
  end
end
