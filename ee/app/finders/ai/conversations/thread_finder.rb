# frozen_string_literal: true

module Ai
  module Conversations
    class ThreadFinder
      def initialize(current_user, params = {})
        @current_user = current_user
        @params = params
      end

      def execute
        relation = current_user.ai_conversation_threads
        relation = by_id(relation)
        relation = by_conversation_type(relation)
        relation = relation.ordered

        # When requesting duo_chat threads but none exist,
        # attempt to copy latest duo_chat_legacy type thread as a duo_chat thread.
        if copy_legacy_thread?(relation)
          legacy_thread = current_user.ai_conversation_threads.duo_chat_legacy.last
          legacy_thread.dup_as_duo_chat_thread! if legacy_thread
          ::Ai::Conversation::LegacyDuoChatCopiedUser.add(current_user.id)
        end

        relation
      end

      private

      attr_reader :current_user, :params

      def by_id(relation)
        return relation unless params[:id]

        relation.id_in(params[:id])
      end

      def by_conversation_type(relation)
        return relation unless params[:conversation_type]

        relation.for_conversation_type(params[:conversation_type])
      end

      def copy_legacy_thread?(relation)
        params[:conversation_type] == 'duo_chat' &&
          params[:id].nil? &&
          relation.empty? &&
          !::Ai::Conversation::LegacyDuoChatCopiedUser.include?(current_user.id) # rubocop:disable Rails/NegateInclude -- no exclude method
      end
    end
  end
end
