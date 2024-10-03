# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    module Probes
      module SelfHosted
        class AiGatewayUrlPresenceProbe < BaseProbe
          extend ::Gitlab::Utils::Override

          ENV_VARIABLE_NAME = 'AI_GATEWAY_URL'

          validate :check_ai_gateway_url_presence

          private

          def self_hosted_url
            ::Gitlab::AiGateway.self_hosted_url
          end

          def check_ai_gateway_url_presence
            return if self_hosted_url.present?

            errors.add(:base, failure_message)
          end

          override :success_message
          def success_message
            format(
              _("Environment variable %{env_variable_name} is set to %{url}."),
              env_variable_name: ENV_VARIABLE_NAME,
              url: self_hosted_url
            )
          end

          def failure_message
            format(
              _("Environment variable %{env_variable_name} is not set."),
              env_variable_name: ENV_VARIABLE_NAME
            )
          end
        end
      end
    end
  end
end
