# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Answers
        class StreamedJson < StreamedAnswer
          def next_chunk(content)
            return if content.empty?

            parser = Parsers::SingleActionParser.new(output: content)
            parser.parse

            return unless parser.final_answer

            payload(parser.final_answer)
          end
        end
      end
    end
  end
end
