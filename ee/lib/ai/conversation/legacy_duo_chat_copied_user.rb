# frozen_string_literal: true

# Record users who have attempted to copy legacy thread (including when none is available to copy)
# This will be removed after we remove `duo_chat_multi_thread` feature flag.
module Ai
  module Conversation
    module LegacyDuoChatCopiedUser
      extend Gitlab::Redis::BackwardsCompatibility

      KEY = 'legacy_duo_chat_copied_user_set'

      class << self
        def add(value)
          Gitlab::Redis::SharedState.with do |redis|
            redis.pipelined do |pipeline|
              pipeline.sadd(KEY, value)
              pipeline.expire(KEY, ::Ai::Conversation::Thread::MAX_EXPIRATION_PERIOD.to_i)
            end
          end
        end

        def include?(value)
          Gitlab::Redis::SharedState.with do |redis|
            redis.sismember(KEY, value)
          end
        end
      end
    end
  end
end
