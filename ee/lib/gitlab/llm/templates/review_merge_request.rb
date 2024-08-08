# frozen_string_literal: true

module Gitlab
  module Llm
    module Templates
      class ReviewMergeRequest
        include Gitlab::Llm::Chain::Concerns::AnthropicPrompt
        include Gitlab::Utils::StrongMemoize

        SYSTEM_MESSAGE = Gitlab::Llm::Chain::Utils::Prompt.as_system(
          <<~PROMPT.chomp
            You are tasked with generating a really helpful code review. The diff will be provided to you, and your job is to analyze the changes and if needed, provide really helpful code suggestions using fenced code blocks and include in your suggestions.
          PROMPT
        )
        USER_MESSAGE = Gitlab::Llm::Chain::Utils::Prompt.as_user(
          <<~PROMPT.chomp
          Git diff of `%<new_path>s`:
          ```
          %<truncated_raw_diff>s
          ```

          Diff hunk of `%<new_path>s`:
          ```
          %<hunk>s
          ```

          Instructions:
          - Review diff hunk of `%<new_path>s` line by line.
          - Use git diff of `%<new_path>s` only for additional context.
          - You must only make really helpful suggestions based on your review.
          - If needed, provide really helpful code suggestions using fenced code blocks and include in your suggestions.
          - Code suggestions must be complete and correctly formatted without line numbers.
          - Your response must only include your really helpful suggestions and must not include mentions of git diff and diff hunk.

          Response:
          PROMPT
        )

        def initialize(new_path, diff, hunk)
          @new_path = new_path
          @diff = diff
          @hunk = hunk
        end

        def to_prompt
          return if truncated_raw_diff.blank?

          {
            messages: Gitlab::Llm::Chain::Utils::Prompt.role_conversation(
              Gitlab::Llm::Chain::Utils::Prompt.format_conversation([USER_MESSAGE], variables)
            ),
            system: Gitlab::Llm::Chain::Utils::Prompt.no_role_text([SYSTEM_MESSAGE], {}),
            model: ::Gitlab::Llm::Anthropic::Client::CLAUDE_3_5_SONNET
          }
        end

        def variables
          {
            new_path: new_path,
            truncated_raw_diff: truncated_raw_diff,
            hunk: hunk
          }
        end

        private

        attr_reader :new_path, :diff, :hunk

        def truncated_raw_diff
          diff.sub(Gitlab::Regex.git_diff_prefix, "").truncate_words(750)
        end
        strong_memoize_attr :truncated_raw_diff
      end
    end
  end
end
