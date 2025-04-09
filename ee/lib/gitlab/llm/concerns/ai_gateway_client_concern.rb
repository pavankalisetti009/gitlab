# frozen_string_literal: true

module Gitlab
  module Llm
    module Concerns
      module AiGatewayClientConcern
        extend ActiveSupport::Concern
        include Gitlab::Utils::StrongMemoize

        # Subclasses must implement this method returning a Hash with all the needed input.
        # An `ArgumentError` can be emitted to signal an error extracting data from the `prompt_message`
        def inputs
          raise NotImplementedError
        end

        private

        def perform_ai_gateway_request!(user:, tracking_context: {})
          ::Gitlab::Llm::AiGateway::Client.new(user, service_name: service_name, tracking_context: tracking_context)
            .complete_prompt(
              base_url: feature_setting&.base_url || ::Gitlab::AiGateway.url,
              prompt_name: prompt_name,
              inputs: inputs,
              prompt_version: prompt_version_or_default,
              model_metadata: model_metadata
            )
        end

        def prompt_version_or_default
          return prompt_version if prompt_version && (!feature_setting&.self_hosted? && !::Ai::AmazonQ.connected?)

          ::Gitlab::Llm::PromptVersions.version_for_prompt(
            service_name,
            model_metadata&.dig(:name)
          )
        end

        def feature_setting
          ::Ai::FeatureSetting.find_by_feature(service_name)
        end
        strong_memoize_attr(:feature_setting)

        def model_metadata
          ::Gitlab::Llm::AiGateway::ModelMetadata.new(feature_setting: feature_setting).to_params
        end
        strong_memoize_attr(:model_metadata)

        # Must be overridden by subclasses to specify the service name.
        def service_name
          raise NotImplementedError
        end

        # Must be overridden by subclasses to specify the prompt name.
        def prompt_name
          raise NotImplementedError
        end

        # Can be overridden by subclasses to specify the prompt template version.
        # If not overridden or returns nil, prompt_version will be set to '^1.0.0'
        def prompt_version
          nil
        end
      end
    end
  end
end
