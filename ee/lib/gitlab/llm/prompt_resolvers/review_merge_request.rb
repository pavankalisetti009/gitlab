# frozen_string_literal: true

module Gitlab
  module Llm
    module PromptResolvers
      class ReviewMergeRequest < Base
        class << self
          def execute(user: nil, _project: nil, _group: nil)
            if ::Ai::AmazonQ.enabled?
              'amazon_q/1.0.0' # Amazon Q
            elsif Feature.enabled?(:duo_code_review_prompt_updates, user)
              '1.3.0' # Claude 4.0 Sonnet with major prompt updates
            else
              '1.2.0' # Claude 4.0 Sonnet
            end
          end
        end
      end
    end
  end
end
