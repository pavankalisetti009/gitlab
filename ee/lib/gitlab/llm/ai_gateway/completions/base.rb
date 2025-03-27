# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      module Completions
        class Base < Llm::Completions::Base
          include Gitlab::Utils::StrongMemoize

          DEFAULT_ERROR = 'An unexpected error has occurred.'
          RESPONSE_MODIFIER = ResponseModifiers::Base

          def execute
            return unless valid?

            response = request!
            response_modifier = self.class::RESPONSE_MODIFIER.new(post_process(response))

            ::Gitlab::Llm::GraphqlSubscriptionResponseService.new(
              user, resource, response_modifier, options: response_options
            ).execute
          end

          # Subclasses must implement this method returning a Hash with all the needed input.
          # An `ArgumentError` can be emitted to signal an error extracting data from the `prompt_message`
          def inputs
            raise NotImplementedError
          end

          private

          # Can be overridden by subclasses to specify the prompt template version.
          # If not overridden or returns nil, no prompt_version will be sent in the request.
          def prompt_version
            nil
          end

          # Can be overwritten by child classes to perform additional validations
          def valid?
            true
          end

          # Can be used by subclasses to perform additional steps or transformations before returning the response data
          def post_process(response)
            response
          end

          def request!
            response = perform_ai_gateway_request!

            return if response&.body.blank?
            return Gitlab::Json.parse(response.body) if response&.success?

            { 'detail' => DEFAULT_ERROR }
          rescue ArgumentError => e
            { 'detail' => e.message }
          rescue StandardError => e
            Gitlab::ErrorTracking.track_exception(e, ai_action: prompt_message.ai_action)

            { 'detail' => DEFAULT_ERROR }
          end

          def perform_ai_gateway_request!
            ::Gitlab::Llm::AiGateway::Client.new(user, service_name: service_name, tracking_context: tracking_context)
              .complete_prompt(
                base_url: feature_setting&.base_url || ::Gitlab::AiGateway.url,
                prompt_name: prompt_message.ai_action,
                inputs: inputs,
                prompt_version: prompt_version_or_default,
                model_metadata: model_metadata
              )
          end

          def prompt_version_or_default
            return prompt_version if prompt_version && (!feature_setting&.self_hosted? && !::Ai::AmazonQ.connected?)

            ::Gitlab::Llm::PromptVersions.version_for_prompt(
              prompt_message.ai_action,
              model_metadata&.dig(:name)
            )
          end

          def feature_setting
            ::Ai::FeatureSetting.find_by_feature(prompt_message.ai_action)
          end
          strong_memoize_attr(:feature_setting)

          def model_metadata
            ::Gitlab::Llm::AiGateway::ModelMetadata.new(feature_setting: feature_setting).to_params
          end
          strong_memoize_attr(:model_metadata)

          def service_name
            prompt_message.ai_action.to_sym
          end
        end
      end
    end
  end
end
