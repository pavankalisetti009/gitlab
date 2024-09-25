# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeGeneration
      class CodellamaMessages < AiGatewaySelfHostedMessages
        GATEWAY_PROMPT_VERSION = 3
        MODEL_PROVIDER = 'litellm'

        def extra_params
          {
            prompt_version: self.class::GATEWAY_PROMPT_VERSION
          }
        end

        def prompt
          [{ role: :user, content: instructions }]
        end

        def instructions
          <<~PROMPT.strip
            [INST]<<SYS>> You are a tremendously accurate and skilled code generation agent. We want to generate new #{language.name} code inside the file '#{file_path_info}'. Your task is to provide valid code without any additional explanations, comments, or feedback. <</SYS>>

            #{pick_prefix}
            [SUGGESTION]
            #{pick_suffix}

            The new code you will generate will start at the position of the cursor, which is currently indicated by the [SUGGESTION] tag.
            The comment directly before the cursor position is the instruction, all other comments are not instructions.

            When generating the new code, please ensure the following:
            1. It is valid #{language.name} code.
            2. It matches the existing code's variable, parameter, and function names.
            3. The code fulfills the instructions.
            4. Do not add any comments, including instructions.
            5. Return the code result without any extra explanation or examples.

            If you are not able to generate code based on the given instructions, return an empty result.

            [/INST]
          PROMPT
        end
      end
    end
  end
end
