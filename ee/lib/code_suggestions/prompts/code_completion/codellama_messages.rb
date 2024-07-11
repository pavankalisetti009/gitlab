# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeCompletion
      class CodellamaMessages < AiGatewayCodeCompletionMessage
        private

        def prompt
          <<~PROMPT.strip
          <PRE> #{pick_prefix} <SUF>#{pick_suffix} <MID>
          PROMPT
        end
      end
    end
  end
end
