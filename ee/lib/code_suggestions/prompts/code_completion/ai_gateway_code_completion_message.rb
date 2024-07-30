# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeCompletion
      class AiGatewayCodeCompletionMessage < CodeSuggestions::Prompts::Base
        GATEWAY_PROMPT_VERSION = 2
        MODEL_PROVIDER = 'litellm'

        attr_reader :feature_setting

        def initialize(feature_setting:, params:)
          @feature_setting = feature_setting

          super(params)
        end

        def params
          self_hosted_model = feature_setting.self_hosted_model

          super.merge({
            model_name: self_hosted_model.model,
            model_endpoint: self_hosted_model.endpoint,
            model_api_key: self_hosted_model.api_token
          })
        end

        def request_params
          {
            model_provider: self.class::MODEL_PROVIDER,
            prompt_version: self.class::GATEWAY_PROMPT_VERSION,
            prompt: prompt,
            model_endpoint: params[:model_endpoint]
          }.tap do |opts|
            opts[:model_name] = params[:model_name] if params[:model_name].present?
            opts[:model_api_key] = params[:model_api_key] if params[:model_api_key].present?
          end
        end

        def prompt
          nil
        end

        private

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
