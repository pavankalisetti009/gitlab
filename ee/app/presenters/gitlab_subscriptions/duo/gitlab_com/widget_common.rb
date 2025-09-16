# frozen_string_literal: true

module GitlabSubscriptions
  module Duo
    module GitlabCom
      module WidgetCommon
        private

        def eligible?
          ::Feature.enabled?(:duo_agent_platform_widget_gitlab_com, namespace) &&
            !namespace.trial? &&
            namespace.licensed_duo_core_features_available?
        end

        def fully_enabled?
          GitlabSubscriptions::Duo.agent_fully_enabled?(namespace)
        end

        def enabled_without_beta_features?
          GitlabSubscriptions::Duo.enabled_without_beta_features?(namespace)
        end

        def only_duo_default_off?
          GitlabSubscriptions::Duo.only_duo_default_off?(namespace)
        end

        def enabled_without_core?
          GitlabSubscriptions::Duo.enabled_without_core?(namespace)
        end
      end
    end
  end
end
