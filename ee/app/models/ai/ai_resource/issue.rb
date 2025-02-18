# frozen_string_literal: true

module Ai
  module AiResource
    class Issue < Ai::AiResource::BaseAiResource
      include Ai::AiResource::Concerns::Noteable

      def serialize_for_ai(content_limit:)
        ::IssueSerializer.new(current_user: current_user, project: resource.project) # rubocop: disable CodeReuse/Serializer
                         .represent(resource, {
                           user: current_user,
                           notes_limit: content_limit,
                           serializer: 'ai',
                           resource: self
                         })
      end

      def current_page_type
        "issue"
      end
    end
  end
end
