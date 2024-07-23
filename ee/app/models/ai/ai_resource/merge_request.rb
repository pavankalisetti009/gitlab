# frozen_string_literal: true

module Ai
  module AiResource
    class MergeRequest < Ai::AiResource::BaseAiResource
      include Ai::AiResource::Concerns::Noteable

      def serialize_for_ai(content_limit:)
        ::MergeRequestSerializer.new(current_user: current_user) # rubocop: disable CodeReuse/Serializer -- existing serializer
                        .represent(resource, {
                          user: current_user,
                          notes_limit: content_limit,
                          serializer: 'ai',
                          resource: self
                        })
      end

      def current_page_type
        "merge_request"
      end

      def current_page_sentence
        return '' unless Feature.enabled?(:ai_merge_request_reader_for_chat, current_user)

        <<~SENTENCE
          The user is currently on a page that displays a merge request with a description, comments, etc., which the user might refer to, for example, as 'current', 'this' or 'that'. The data is provided in <resource></resource> tags, and if it is sufficient in answering the question, utilize it instead of using the 'MergeRequestReader' tool.
        SENTENCE
      end

      def current_page_short_description
        return '' unless Feature.enabled?(:ai_merge_request_reader_for_chat, current_user)

        <<~SENTENCE
          The user is currently on a page that displays a merge request with a description, comments, etc., which the user might refer to, for example, as 'current', 'this' or 'that'. The title of the merge request is '#{resource.title}'. Remember to use the 'MergeRequestReader' tool if they ask a question about the Merge Request.
        SENTENCE
      end
    end
  end
end
