# frozen_string_literal: true

module Gitlab
  module Llm
    class ChatStorage
      class Postgresql < Base
        DEFAULT_CONVERSATION_TYPE = :duo_chat_legacy
        MAX_MESSAGES = 50

        def add(message)
          # Message is stored only partially. Some data might be missing after reloading from storage.
          data = message.to_h.slice(*%w[role referer_url])

          extras = message.extras
          if message.additional_context.present?
            extras ||= {}
            extras['additional_context'] = message.additional_context.to_a
          end

          data['extras'] = extras.to_json if extras
          data['content'] = message.content[0, MAX_TEXT_LIMIT] if message.content
          data['message_xid'] = message.id if message.id
          data['error_details'] = message.errors.to_json if message.errors
          data['request_xid'] = message.request_id if message.request_id

          data.compact!

          result = current_thread.messages.create!(**data)
          current_thread.update_column(:last_updated_at, Time.current)
          clear_memoization(:messages)

          result
        end

        def set_has_feedback(message)
          user.ai_conversation_messages.for_id(message.id).update!(has_feedback: true)
          clear_memoization(:messages)
        end

        def messages
          return [] unless current_thread

          current_thread.messages.recent(MAX_MESSAGES).map do |message|
            data = message.as_json

            data['id'] = data.delete('message_xid') if data['message_xid']
            data['errors'] = data.delete('error_details') if data['error_details']
            data['request_id'] = data['request_xid'] if data['request_xid']
            data['timestamp'] = data['created_at']

            msg = load_message(data)

            msg.extras['has_feedback'] = data.delete('has_feedback') if data['has_feedback']
            msg.active_record = message
            msg.thread = current_thread

            msg
          end
        end
        strong_memoize_attr :messages

        def clear!
          @current_thread = current_thread.to_new_thread!
          clear_memoization(:messages)
        end

        def update_message_extras(message)
          user.ai_conversation_messages.for_id(message.id).update!(extras: message.extras.to_json)
          clear_memoization(:messages)
        end

        def current_thread
          @current_thread ||= thread
          @current_thread ||= find_default_thread || create_default_thread if @thread_fallback
        end

        private

        def find_default_thread
          user.ai_conversation_threads.for_conversation_type(DEFAULT_CONVERSATION_TYPE).last
        end

        def create_default_thread
          user.ai_conversation_threads.create!(conversation_type: DEFAULT_CONVERSATION_TYPE)
        end
      end
    end
  end
end
