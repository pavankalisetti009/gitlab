# frozen_string_literal: true

module GitlabSubscriptions
  module Duo
    module SelfManaged
      class AuthorizedAgentPlatformWidgetPresenter < Duo::BaseAgentPlatformWidgetPresenter
        RELEASE_DATE = Date.new(2025, 9, 18)
        private_constant :RELEASE_DATE

        private

        def eligible?
          return false unless on_or_past_release_date?
          return false if ::Feature.disabled?(:duo_agent_platform_widget_self_managed, :instance)
          return false if amazon_q_customer?
          return false if self_hosted_ai_gateway?
          return false if dedicated?

          License.duo_core_features_available?
        end

        def dedicated?
          ::Gitlab::CurrentSettings.gitlab_dedicated_instance?
        end

        def on_or_past_release_date?
          Date.current >= RELEASE_DATE
        end

        def amazon_q_customer?
          ::Ai::AmazonQ.enabled?
        end

        def self_hosted_ai_gateway?
          ::Gitlab::DuoWorkflow::Client.self_hosted_url.present?
        end

        def enabled_without_beta_features?
          GitlabSubscriptions::Duo.self_managed_enabled_without_beta_features?
        end

        def fully_enabled?
          GitlabSubscriptions::Duo.self_managed_agent_fully_enabled?
        end

        def only_duo_default_off?
          GitlabSubscriptions::Duo.self_managed_only_duo_default_off?
        end

        def enabled_without_core?
          GitlabSubscriptions::Duo.self_managed_enabled_without_core?
        end

        def action_path
          ::Gitlab::Routing.url_helpers.update_duo_agent_platform_admin_application_settings_path
        end
      end
    end
  end
end
