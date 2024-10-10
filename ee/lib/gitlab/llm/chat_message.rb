# frozen_string_literal: true

module Gitlab
  module Llm
    class ChatMessage < AiMessage
      RESET_MESSAGE = '/reset'
      CLEAR_HISTORY_MESSAGE = '/clear'

      def save!
        storage = ChatStorage.new(user, agent_version_id)

        if content == CLEAR_HISTORY_MESSAGE
          storage.clear!
        else
          storage.add(self)
        end
      end

      def conversation_reset?
        content == RESET_MESSAGE
      end

      def clear_history?
        content == CLEAR_HISTORY_MESSAGE
      end

      def question?
        user? && !conversation_reset? && !clear_history?
      end

      def chat?
        true
      end
    end
  end
end
