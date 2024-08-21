# frozen_string_literal: true

module Gitlab
  module Llm
    module Templates
      class GitCommand
        include Gitlab::Llm::Chain::Concerns::AnthropicPrompt

        SYSTEM_MESSAGE = Gitlab::Llm::Chain::Utils::Prompt.as_system(
          <<~PROMPT.chomp
          You are tasked to provide a list of appropriate git commands from natural language.
          PROMPT
        )
        USER_MESSAGE = Gitlab::Llm::Chain::Utils::Prompt.as_user(
          <<~PROMPT.chomp
          Provide the appropriate git commands for: %<prompt>s.

          Respond with git commands wrapped in separate ``` blocks.
          Provide explanation for each command in a separate block.

          ## Example:

          ```
          git log -10
          ```

          This command will list the last 10 commits in the current branch.
          PROMPT
        )

        def initialize(prompt)
          @prompt = prompt
        end

        def to_prompt
          {
            messages: Gitlab::Llm::Chain::Utils::Prompt.role_conversation(
              Gitlab::Llm::Chain::Utils::Prompt.format_conversation([USER_MESSAGE], variables)
            ),
            system: Gitlab::Llm::Chain::Utils::Prompt.no_role_text([SYSTEM_MESSAGE], {}),
            model: ::Gitlab::Llm::Anthropic::Client::CLAUDE_3_HAIKU
          }
        end

        private

        attr_reader :prompt

        def variables
          { prompt: prompt }
        end
      end
    end
  end
end
