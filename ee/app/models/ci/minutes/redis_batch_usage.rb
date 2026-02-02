# frozen_string_literal: true

module Ci
  module Minutes
    # Handles Redis-based batching of CI minutes usage to reduce database contention.
    # This model encapsulates all Redis operations for accumulating usage data
    # before periodic flushing to the database.
    class RedisBatchUsage
      include Gitlab::ExclusiveLeaseHelpers

      VALID_FIELDS = %w[amount_used shared_runners_duration].freeze
      TTL_SECONDS = 86400 # 24 hours as safety net
      KEY_PREFIX = 'minutes_batch:namespace_monthly_usages'

      attr_reader :namespace_id

      def initialize(namespace_id:)
        @namespace_id = namespace_id
      end

      def batch_increment(amount_used: 0, shared_runners_duration: 0)
        increment_params = {}
        increment_params[:amount_used] = amount_used if amount_used > 0
        increment_params[:shared_runners_duration] = shared_runners_duration if shared_runners_duration > 0

        return if increment_params.empty?

        with_redis do |redis|
          redis.pipelined do |pipeline|
            increment_params.each do |field, value|
              pipeline.hincrbyfloat(redis_key, field.to_s, value)
            end
            pipeline.expire(redis_key, TTL_SECONDS)
          end
        end
      end

      # @param field [String, Symbol] The field name to fetch specified by VALID_FIELDS
      # @return [Float] The accumulated value, or 0.0 if not found or on error
      def fetch_field(field)
        return 0.0 unless VALID_FIELDS.include?(field.to_s)

        with_redis do |redis|
          redis.hget(redis_key, field.to_s).to_f
        end
      rescue StandardError => e
        Gitlab::ErrorTracking.track_and_raise_for_dev_exception(
          e,
          namespace_id: namespace_id,
          field: field,
          redis_key: redis_key
        )
        0.0
      end

      # @return [Hash] Hash with field names as keys and accumulated values
      def fetch_all_fields
        with_redis do |redis|
          data = redis.hgetall(redis_key)
          data.transform_values(&:to_f)
        end
      rescue StandardError => e
        Gitlab::ErrorTracking.track_and_raise_for_dev_exception(
          e,
          namespace_id: namespace_id,
          redis_key: redis_key
        )
        {}
      end

      def delete_key
        with_redis do |redis|
          redis.del(redis_key)
        end
      end

      # @return [String] The Redis key for this namespace
      def redis_key
        "#{KEY_PREFIX}:{#{namespace_id}}"
      end

      # @return [String] The lock key for coordinating flush operations
      def lock_key
        "#{redis_key}:lock"
      end

      def with_redis
        Gitlab::Redis::SharedState.with { |redis| yield(redis) }
      end
    end
  end
end
