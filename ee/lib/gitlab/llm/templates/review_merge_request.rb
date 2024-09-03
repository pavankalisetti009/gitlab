# frozen_string_literal: true

module Gitlab
  module Llm
    module Templates
      class ReviewMergeRequest
        include Gitlab::Llm::Chain::Concerns::AnthropicPrompt
        include Gitlab::Utils::StrongMemoize

        SYSTEM_MESSAGE = Gitlab::Llm::Chain::Utils::Prompt.as_system(
          <<~PROMPT.chomp
            You are an experienced software developer tasked with reviewing code changes made by your colleague in a GitLab merge request. Your goal is to review the changes thoroughly and offer constructive and concise feedback when you identify any issues or areas of improvement.
          PROMPT
        )
        USER_MESSAGE = Gitlab::Llm::Chain::Utils::Prompt.as_user(
          <<~PROMPT.chomp
            You will be provided with a filename and a git diff hunk from a GitLab merge request. A git diff hunk represents a contiguous group of lines that have been modified, added, or removed between two versions of a file. Git hunk might also includes a few lines of context around the changed lines to provide better understanding of where the changes occur. Added lines are prefixed with '+', removed lines prefixed with '-', and unchanged lines have no prefixes.

            Here is the filename of the git diff hunk:

            <filename>
            %{new_path}
            </filename>

            Here is the git diff hunk you need to review:

            <git_diff_hunk>
            %{hunk}
            </git_diff_hunk>

            Review the code changes carefully, focus on the following criteria:
            1. Code correctness and functionality
            2. Code efficiency and performance impact
            3. Security considerations
            4. Potential bugs or edge cases
            5. Readability and maintainability
            6. Code style and adherence to best practices

            Provide feedback only if you identify issues or areas for improvement, otherwise just respond with '<no_issues_found/>' as your entire response.

            Guidelines for your review:
            - Be specific and provide clear explanations of your suggestions or concerns
            - Offer both constructive criticism and positive feedback where appropriate
            - List your feedback in the order of significance when providing feedback
            - Use the following formats for your feedback:
               - For non-code feedback:
                 1. [Your first point]
                 2. [Your second point]
                 3. [Your third point]
               - For code suggestions:
                 ```
                 def add(a, b)
                   a + b
                 end
                 ```
            - List your non-code feedback first then make a code suggestion at the end with a short summary

            Remember to be constructive and professional in your feedback, as your goal is to improve the code quality and help your fellow developers to apply these changes efficiently.
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
