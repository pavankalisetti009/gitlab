# frozen_string_literal: true

module Gitlab
  module Llm
    module Anthropic
      module ResponseModifiers
        class GitCommand < Gitlab::Llm::BaseResponseModifier
          def response_body
            content = ai_response&.dig('content', 0, 'text')

            return if content.blank?

            # Need to format the response like this since glab client expects
            # the response from API like this. Even if we change glab to parse
            # a different format, we also need to support older clients.
            {
              predictions: [
                {
                  candidates: [
                    {
                      content: content
                    }
                  ]
                }
              ]
            }
          end

          def errors
            @errors ||= [ai_response&.dig('error', 'message')].compact
          end
        end
      end
    end
  end
end
