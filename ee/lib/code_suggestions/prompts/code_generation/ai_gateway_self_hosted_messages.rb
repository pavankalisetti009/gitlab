# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeGeneration
      class AiGatewaySelfHostedMessages < CodeSuggestions::Prompts::Base
        GATEWAY_PROMPT_VERSION = 2
        MODEL_PROVIDER = 'litellm'
        PROMPT_ID = 'code_suggestions/generations'

        attr_reader :feature_setting

        def initialize(feature_setting:, params:)
          @feature_setting = feature_setting

          super(params)
        end

        def request_params
          self_hosted_model = feature_setting&.self_hosted_model

          {
            model_provider: self.class::MODEL_PROVIDER,
            prompt: prompt,
            model_endpoint: self_hosted_model&.endpoint,
            model_api_key: self_hosted_model&.api_token,
            model_name: self_hosted_model&.model
          }.merge(extra_params)
        end

        private

        def extra_params
          {
            prompt_version: self.class::GATEWAY_PROMPT_VERSION,
            prompt_id: PROMPT_ID
          }
        end

        def prompt
          params[:instruction]&.instruction.presence || ""
        end

        def pick_prefix
          prefix.last(500)
        end

        def pick_suffix
          suffix.first(500)
        end
      end
    end
  end
end
