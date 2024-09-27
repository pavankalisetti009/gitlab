# frozen_string_literal: true

module Gitlab
  module Llm
    module Templates
      class ReviewMergeRequest
        include Gitlab::Llm::Chain::Concerns::AnthropicPrompt
        include Gitlab::Utils::StrongMemoize

        SYSTEM_MESSAGE = Gitlab::Llm::Chain::Utils::Prompt.as_system(
          <<~PROMPT.chomp
            You are an experienced software developer tasked with reviewing code changes made by your colleague in a GitLab merge request. Your goal is to review the changes thoroughly and offer constructive and yet concise feedback if required.
          PROMPT
        )
        USER_MESSAGE = Gitlab::Llm::Chain::Utils::Prompt.as_user(
          <<~PROMPT.chomp
            First, you will be given a filename and the raw git diff of that file. This diff contains the changes made in the MR that you need to review.

            Here is the filename of the git diff:

            <filename>
            %{new_path}
            </filename>

            Here is the git diff you need to review:

            <git_diff>
            %{diff}
            </git_diff>

            To properly review this MR, follow these steps:

            1. Parse the git diff:
               - The diff contains hunk headers that look like this: @@ -1,7 +1,6 @@
               - Use these headers to determine the correct line numbers for each changed line
               - Lines starting with '-' are removals, '+' are additions, and ' ' (space) are unchanged context lines
               - Do not skip any blank lines after the hunk header when determining line numbers

            2. Analyze the changes carefully, strictly focus on the following criteria:
               - Code correctness and functionality
               - Code efficiency and performance impact
               - Potential security vulnerabilities like SQL injection, XSS, etc.
               - Potential bugs or edge cases that may have missed
               - Do not comment on documentations

            3. Formulate your comments:
               - Determine the most appropriate line for your comment and provide that as the line number for the comment.
               - When you notice multiple issues on the same line, leave only one comment on that line and list your issues together. List comments from highest in priority to the lowest.
               - Assign each comment a priority from 1 to 3:
                 - Priority 1: Not important
                 - Priority 2: Helpful but can be ignored
                 - Priority 3: Important, helpful and required

            4. Format your comments:
               - Wrap each comment in a <comment> element
               - Include a 'priority' attribute with the assigned priority (1, 2, or 3)
               - Include a 'line' attribute with the most relevant line number from the Git diff
               - When suggesting a code change, use code block format ```[your code suggestion]```
               - Wrap your entire response in `<review></review>` tag.
               - Just return `<review></review>` as your entire response, if the change is acceptable

            Remember to only focus on substantive feedback that will genuinely improve the code or prevent potential issues. Do not nitpick or comment on trivial matters.

            Begin your review now.
          PROMPT
        )

        def initialize(new_path, diff, hunk)
          @new_path = new_path
          @diff = diff
          @hunk = hunk
        end

        def to_prompt
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
            diff: diff
          }
        end

        private

        attr_reader :new_path, :diff, :hunk
      end
    end
  end
end
