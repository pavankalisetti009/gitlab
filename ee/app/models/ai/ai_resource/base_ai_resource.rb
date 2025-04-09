# frozen_string_literal: true

module Ai
  module AiResource
    class BaseAiResource
      CHAT_QUESTIONS = [].freeze

      CHAT_UNIT_PRIMITIVE = :duo_chat

      attr_reader :resource, :current_user

      def initialize(user, resource)
        @resource = resource
        @current_user = user
      end

      def serialize_for_ai(_content_limit:)
        raise NotImplementedError
      end

      def current_page_params
        {
          type: current_page_type,
          title: resource.title
        }
      end

      def current_page_type
        raise NotImplementedError
      end

      def chat_questions
        self.class::CHAT_QUESTIONS
      end

      def chat_unit_primitive
        self.class::CHAT_UNIT_PRIMITIVE
      end
    end
  end
end
