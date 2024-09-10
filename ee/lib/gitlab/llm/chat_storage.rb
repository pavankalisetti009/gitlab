# frozen_string_literal: true

module Gitlab
  module Llm
    class ChatStorage
      include Gitlab::Utils::StrongMemoize

      # Expiration time of user messages should not be more than 90 days.
      # EXPIRE_TIME sets expiration time for the whole chat history stream (not
      # for individual messages) - so the stream is deleted after 3 days since
      # last message was added.  Because for each user's message there is also
      # a response, it means that maximum theoretical time of oldest message in
      # the stream is (MAX_MESSAGES / 2) * EXPIRE_TIME
      EXPIRE_TIME =  3.days
      MAX_MESSAGES = 50
      # AI provider-specific limits are applied to requests/responses. To not
      # rely only on third-party limits and assure that cache usage can't be
      # exhausted by users by sending huge texts/responses, we apply also
      # safeguard limit on maximum size of cached response. 1 token ~= 4 chars
      # in English, limit is typically ~4100 -> so 20000 char limit should be
      # sufficient.
      MAX_TEXT_LIMIT = 20_000

      def initialize(user, agent_version_id = nil)
        @user = user
        @agent_version_id = agent_version_id
      end

      def add(message)
        cache_data(dump_message(message))
        clear_memoization(:messages)
      end

      def set_has_feedback(message)
        with_redis do |redis|
          redis.multi do |multi|
            multi.sadd(feedback_key, [message.id])
            multi.expire(feedback_key, EXPIRE_TIME)
          end
        end
        clear_memoization(:messages)
      end

      def messages
        with_redis do |redis|
          feedback_markers = redis.smembers(feedback_key)
          redis.xrange(key).map do |_id, data|
            load_message(data).tap { |message| message.extras['has_feedback'] = feedback_markers.include?(message.id) }
          end
        end
      end
      strong_memoize_attr :messages

      def messages_by(filters = {})
        messages.select do |message|
          matches_filters?(message, filters)
        end
      end

      def last_conversation
        self.class.last_conversation(messages)
      end

      def self.last_conversation(messages)
        idx = messages.rindex(&:conversation_reset?)
        return messages unless idx
        return [] unless idx + 1 < messages.size

        messages[idx + 1..]
      end

      def messages_up_to(message_id)
        all = messages
        idx = all.rindex { |m| m.id == message_id }
        idx ? all.first(idx + 1) : []
      end

      def clean!
        with_redis do |redis|
          redis.xtrim(key, 0)
          redis.del(feedback_key)
        end
        clear_memoization(:messages)
      end

      private

      attr_reader :user, :agent_version_id

      def cache_data(data)
        with_redis do |redis|
          redis.multi do |multi|
            multi.xadd(key, data, maxlen: MAX_MESSAGES)
            multi.expire(key, EXPIRE_TIME)
          end
        end
      end

      def key
        return "ai_chat:#{user.id}:#{agent_version_id}" if agent_version_id

        "ai_chat:#{user.id}"
      end

      def feedback_key
        "#{key}:feedback"
      end

      def with_redis(&block)
        Gitlab::Redis::Chat.with(&block) # rubocop: disable CodeReuse/ActiveRecord
      end

      def matches_filters?(message, filters)
        return false if filters[:roles]&.exclude?(message.role)
        return false if filters[:request_ids]&.exclude?(message.request_id)

        true
      end

      def dump_message(message)
        # Message is stored only partially. Some data might be missing after reloading from storage.
        result = message.to_h.slice(*%w[id request_id role content referer_url])

        result['errors'] = message.errors&.to_json
        result['extras'] = message.extras&.to_json
        result['timestamp'] = message.timestamp&.to_s
        result['content'] = result['content'][0, MAX_TEXT_LIMIT] if result['content']
        result['additional_context'] = message.additional_context.to_a.to_json if message.additional_context.present?

        result.compact
      end

      def load_message(data)
        data['extras'] = ::Gitlab::Json.parse(data['extras']) if data['extras']
        data['errors'] = ::Gitlab::Json.parse(data['errors']) if data['errors']
        data['timestamp'] = Time.zone.parse(data['timestamp']) if data['timestamp']
        data['ai_action'] = 'chat'
        data['user'] = user
        data['agent_version_id'] = agent_version_id
        data['additional_context'] = ::Gitlab::Json.parse(data['additional_context']) if data['additional_context']

        ChatMessage.new(data)
      end
    end
  end
end
