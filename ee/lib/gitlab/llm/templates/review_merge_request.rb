# frozen_string_literal: true

module Gitlab
  module Llm
    module Templates
      class ReviewMergeRequest
        include Gitlab::Utils::StrongMemoize

        def initialize(new_path, diff, hunk)
          @new_path = new_path
          @diff = diff
          @hunk = hunk
        end

        def to_prompt
          return if truncated_raw_diff.blank?

          <<~PROMPT
Git diff of `#{new_path}`:
```
#{truncated_raw_diff}
```

Diff hunk of `#{new_path}`:
```
#{hunk}
```

Instructions:
- Review diff hunk of `#{new_path}` line by line.
- Use git diff of `#{new_path}` only for additional context.
- You must only make really helpful suggestions based on your review.
- If needed, provide really helpful code suggestions using fenced code blocks and include in your suggestions.
- Code suggestions must be complete and correctly formatted without line numbers.
- Your response must only include your really helpful suggestions and must not include mentions of git diff and diff hunk.

Response:
          PROMPT
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
