# frozen_string_literal: true

module Gitlab
  module Llm
    module Anthropic
      module Completions
        class ReviewMergeRequest
          class ResponseBodyParser
            include ::Gitlab::Utils::StrongMemoize

            class Comment
              ATTRIBUTES = %w[priority old_line new_line].freeze

              attr_reader :attributes, :content

              def initialize(attrs, content)
                @attributes = attrs
                @content = content
              end

              ATTRIBUTES.each do |attr|
                define_method(attr) do
                  Integer(attributes[attr], exception: false)
                end
              end

              def valid?
                return false if priority.blank? || content.blank?
                return false if old_line.blank? && new_line.blank?

                true
              end
            end

            attr_reader :response

            def initialize(response)
              @response = response
            end

            def comments
              return [] if response.blank?

              review_content = response.match(review_wrapper_regex)

              return [] if review_content.blank?

              review_content[1].scan(comment_wrapper_regex).filter_map do |attrs, body|
                comment = Comment.new(parsed_attrs(attrs), parsed_content(body))
                comment if comment.valid?
              end
            end
            strong_memoize_attr :comments

            private

            def review_wrapper_regex
              %r{^<review>(.+)</review>$}m
            end

            def comment_wrapper_regex
              %r{^<comment (.+?)>(?:\n?)(.+?)</comment>$}m
            end

            def comment_attr_regex
              %r{([^\s]*?)="(.*?)"}
            end

            def code_suggestion_regex
              # NOTE: We might get multiple code suggestions on the same line as that's still valid so we should take
              #   that possibility of extra `<from>` into account here.
              #   Also, sometimes LLM returns tags inline like `<to>  some text</to>` for single line suggestions which
              #   we need to handle as well just in case.
              %r{(.*?)^(?:<from>\n(.*?)^</from>\n<to>(.*?)^</to>|<from>(.+?)</from>\n<to>(.+?)</to>)(.*?)(?=<from>|\z)}m
            end

            def parsed_attrs(attrs)
              Hash[attrs.scan(comment_attr_regex)]
            end

            def parsed_content(body)
              body_with_suggestions = body
                .scan(code_suggestion_regex)
                .map do |header, multiline_from, multiline_to, inline_from, inline_to, footer|
                  # NOTE: We're just interested in counting the existing lines as LLM doesn't
                  #   seem to be able to reliably set this by itself.
                  #   Also, since we have two optional matching pairs so either `multiline_from` and `multiline_to` or
                  #   `inline_from` and `inline_to` would exist.
                  line_offset_below = (multiline_from || inline_from).lines.count - 1

                  # NOTE: Inline code suggestion needs to be wrapped in new lines to format it correctly.
                  comment = inline_to.nil? ? multiline_to : "\n#{inline_to}\n"

                  "#{header}```suggestion:-0+#{line_offset_below}#{comment}```#{footer}"
                end

              # NOTE: Return original body if the body doesn't have any expected suggestion format.
              return body unless body_with_suggestions.present?

              body_with_suggestions.join
            end
          end
        end
      end
    end
  end
end
