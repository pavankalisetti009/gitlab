# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      module Completions
        class ReviewMergeRequest
          class ResponseBodyParser
            include ::Gitlab::Utils::StrongMemoize

            class Comment
              ATTRIBUTES = %w[old_line new_line file].freeze

              attr_reader :attributes, :content, :from

              def initialize(attrs, content, from)
                @attributes = attrs
                @content = content
                @from = from
              end

              ATTRIBUTES.each do |attr|
                define_method(attr) do
                  attr == 'file' ? attributes[attr] : Integer(attributes[attr], exception: false)
                end
              end

              def valid?
                return false if content.blank?
                return false if old_line.blank? && new_line.blank?

                # Always require the file attribute since we now include it in all cases,
                # even for single-file reviews
                return false if file.blank?

                true
              end
            end

            attr_reader :response

            def initialize(response)
              @response = response
            end

            def comments
              return [] if response.blank?

              review_block = extract_review_block
              return [] if review_block.blank?

              review_block.scan(comment_wrapper_regex).filter_map do |attrs, body|
                parsed_body = parsed_content(body)
                comment = Comment.new(parsed_attrs(attrs), parsed_body[:body], parsed_body[:from])
                comment if comment.valid?
              end
            end
            strong_memoize_attr :comments

            private

            def extract_review_block
              # Find the last occurrence of <review>...</review> in the response
              # This ensures we get the actual review output, not any examples in thinking steps
              matches = response.scan(%r{<review>.*?</review>}m)
              matches.last
            end

            def comment_wrapper_regex
              %r{^<comment (.+?)>(?:\n?)(.+?)</comment>$}m
            end

            def comment_attr_regex
              %r{([^\s]*?)="(.*?)"}
            end

            def parsed_attrs(attrs)
              Hash[attrs.scan(comment_attr_regex)]
            end

            def parsed_content(body)
              ::Gitlab::Llm::Utils::CodeSuggestionFormatter.parse(body)
            end
          end
        end
      end
    end
  end
end
