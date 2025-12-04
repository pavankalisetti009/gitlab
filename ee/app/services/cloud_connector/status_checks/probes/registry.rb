# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    module Probes
      class Registry
        CUSTOMERS_DOT_URL = ::Gitlab::Routing.url_helpers.subscription_portal_url.freeze
        CLOUD_CONNECTOR_URL = ::CloudConnector::Config.base_url.freeze

        def initialize(user)
          @user = user
        end

        # Carries out minimal checks for development and testing purposes
        def development_probes
          [
            ::CloudConnector::StatusChecks::Probes::HostProbe.new(::Gitlab::AiGateway.self_hosted_url),
            ::CloudConnector::StatusChecks::Probes::EndToEndProbe.new(@user)
          ]
        end

        def amazon_q_probes
          [
            ::CloudConnector::StatusChecks::Probes::AmazonQ::EndToEndProbe.new(@user)
          ]
        end

        def self_hosted_probes
          if Feature.enabled?(:ai_self_hosted_vendored_features, :instance) && at_least_one_vendored_feature?
            probes_for_vendored_features + self_hosted_only_probes
          else
            self_hosted_only_probes
          end
        end

        def default_probes
          [
            ::CloudConnector::StatusChecks::Probes::LicenseProbe.new,
            ::CloudConnector::StatusChecks::Probes::HostProbe.new(CUSTOMERS_DOT_URL),
            ::CloudConnector::StatusChecks::Probes::HostProbe.new(CLOUD_CONNECTOR_URL),
            ::CloudConnector::StatusChecks::Probes::AccessProbe.new,
            ::CloudConnector::StatusChecks::Probes::TokenProbe.new,
            ::CloudConnector::StatusChecks::Probes::EndToEndProbe.new(@user),
            ::CloudConnector::StatusChecks::Probes::DuoAgentPlatformProbe.new(@user)
          ]
        end

        private

        def probes_for_vendored_features
          return default_probes if code_completions_is_vendored?

          # If code completions is not vendored, we need to remove the end to end probe
          default_probes.reject { |probe| probe.is_a?(::CloudConnector::StatusChecks::Probes::EndToEndProbe) }
        end

        def self_hosted_only_probes
          [
            ::CloudConnector::StatusChecks::Probes::SelfHosted::AiGatewayUrlPresenceProbe.new,
            ::CloudConnector::StatusChecks::Probes::HostProbe.new(::Gitlab::AiGateway.self_hosted_url),
            ::CloudConnector::StatusChecks::Probes::SelfHosted::CodeSuggestionsLicenseProbe.new(@user)
          ]
        end

        def at_least_one_vendored_feature?
          ::Ai::FeatureSetting.vendored.exists?
        end

        def code_completions_is_vendored?
          ::Ai::FeatureSetting.vendored.find_by_feature(:code_completions).present?
        end
      end
    end
  end
end
