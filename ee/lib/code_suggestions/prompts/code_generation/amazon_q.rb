# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeGeneration
      class AmazonQ < AiGatewayMessages
        MODEL_PROVIDER = 'amazon_q'

        def request_params
          {
            prompt_components: [
              {
                type: PROMPT_COMPONENT_TYPE,
                payload: {
                  file_name: file_name,
                  content_above_cursor: content_above_cursor,
                  content_below_cursor: content_below_cursor,
                  language_identifier: language.name,
                  stream: params.fetch(:stream, false),
                  model_provider: self.class::MODEL_PROVIDER,
                  model_name: self.class::MODEL_PROVIDER,
                  role_arn: ::Ai::Setting.instance.amazon_q_role_arn
                }
              }
            ]
          }
        end
      end
    end
  end
end
