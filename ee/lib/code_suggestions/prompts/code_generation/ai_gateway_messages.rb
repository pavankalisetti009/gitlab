# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeGeneration
      class AiGatewayMessages < CodeSuggestions::Prompts::Base
        include Gitlab::Utils::StrongMemoize

        PROMPT_COMPONENT_TYPE = 'code_editor_generation'
        PROMPT_ID = 'code_suggestions/generations'

        # response time grows with prompt size, so we don't use upper limit size of prompt window
        MAX_INPUT_CHARS = 50000
        GATEWAY_PROMPT_VERSION = 3
        CONTENT_TYPES = { file: 'file', snippet: 'snippet' }.freeze

        def request_params
          {
            prompt_components: [
              {
                type: PROMPT_COMPONENT_TYPE,
                payload: {
                  file_name: file_name,
                  content_above_cursor: prefix,
                  content_below_cursor: suffix,
                  language_identifier: language.name,
                  prompt_id: PROMPT_ID,
                  prompt_enhancer: code_generation_enhancer
                }
              }
            ]
          }
        end

        private

        def code_generation_enhancer
          {
            **examples_section_params,
            **existing_code_block_params
          }
        end

        def examples_section_params
          {
            # TODO: we can migrate all examples to AIGW as followup,
            # eg: CODE_GENERATIONS_EXAMPLES_URI = 'ee/lib/code_suggestions/prompts/code_generation/examples.yml'
            examples_array: language.generation_examples(type: params[:instruction]&.trigger_type)
          }
        end

        def existing_code_block_params
          return {} unless params[:prefix].present?

          trimmed_prefix = prefix.to_s.last(MAX_INPUT_CHARS)
          trimmed_suffix = suffix.to_s.first(MAX_INPUT_CHARS - trimmed_prefix.size)

          {
            trimmed_prefix: trimmed_prefix,
            trimmed_suffix: trimmed_suffix
          }
        end
      end
    end
  end
end
