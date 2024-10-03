# frozen_string_literal: true

module Gitlab
  module Ai
    module SelfHosted
      module AiGateway
        extend self

        # An instance having an offline cloud license is
        # supposed to be an air-gapped instance.
        # Air-gapped instances cannot connect to GitLab's default CloudConnector
        # and are hence required to self-host their own AI Gateway (and the models)
        def required?
          ::Feature.enabled?(:ai_custom_model) && # rubocop:disable Gitlab/FeatureFlagWithoutActor -- The feature flag is global
            ::License.current&.offline_cloud_license?
        end

        def probes(user)
          [
            ::CloudConnector::StatusChecks::Probes::SelfHosted::AiGatewayUrlPresenceProbe.new,
            ::CloudConnector::StatusChecks::Probes::HostProbe.new(::Gitlab::AiGateway.self_hosted_url),
            ::CloudConnector::StatusChecks::Probes::SelfHosted::CodeSuggestionsLicenseProbe.new(user),
            ::CloudConnector::StatusChecks::Probes::EndToEndProbe.new(user)
          ]
        end
      end
    end
  end
end
