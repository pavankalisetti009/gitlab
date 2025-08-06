# frozen_string_literal: true

module Gitlab
  module Llm
    module PromptResolvers
      class ReviewMergeRequest < Base
        class << self
          def execute(user: nil, _project: nil, group: nil)
            # For specific customers, we want to use Claude 3.5 Sonnet for Duo Code Reviews
            # It uses the `use_claude_code_completion` feature flag because
            # it is tied to the usage of Claude models for AI features, so it is apt to use it here
            # as well. This check can be removed once we have enabled model switching.
            if Feature.enabled?(:use_claude_code_completion, group)
              '0.9.0' # Claude 3.5 Sonnet
            elsif ::Ai::AmazonQ.enabled?
              'amazon_q/1.0.0' # Amazon Q
            elsif Feature.enabled?(:duo_code_review_prompt_updates, user)
              '1.3.0' # Claude 4.0 Sonnet with major prompt updates
            elsif Feature.enabled?(:duo_code_review_custom_instructions, user)
              '1.2.0' # Claude 4.0 Sonnet with custom instructions
            elsif Feature.enabled?(:duo_code_review_claude_4_0_rollout, user)
              '1.1.0' # Claude 4.0 Sonnet
            else
              '1.0.0' # Claude 3.7 Sonnet
            end
          end
        end
      end
    end
  end
end
