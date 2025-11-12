# frozen_string_literal: true

module AntiAbuse
  module IdentityVerification
    # Track Arkose token verification results for the current BUCKET_DURATION_HOURS window (00-03:59, 04:00-07:59, ...).
    # This data will be used later to track token verification rate per BUCKET_DURATION_HOURS window.
    module ArkoseFailOpen
      extend self

      BUCKET_DURATION_HOURS              = 4
      BUCKET_DURATION_SECONDS            = BUCKET_DURATION_HOURS.hours.to_i
      COUNTER_SUCCESS_KEY_PREFIX       = 'arkose:token_verification:success:'
      COUNTER_FAILURE_KEY_PREFIX       = 'arkose:token_verification:failure:'

      def track_token_verification_result(success:)
        return unless feature_enabled?

        prefix = success ? COUNTER_SUCCESS_KEY_PREFIX : COUNTER_FAILURE_KEY_PREFIX
        increment_counter!(prefix)
      rescue Redis::BaseError => e
        Gitlab::ErrorTracking.track_exception(e)
      end

      private

      def feature_enabled?
        Feature.enabled?(:track_arkose_token_verification_results, :instance)
      end

      def increment_counter!(prefix)
        key = bucket_counter_key(prefix)
        with_redis do |redis|
          redis.multi do |transaction|
            transaction.incr(key)

            # NOTE: We are only interested in token verification request result counters in the current window
            # so we let counters older than two windows expire.
            transaction.expire(key, BUCKET_DURATION_SECONDS * 2, nx: true)
          end
        end
      end

      # NOTE: bucket_counter_keys look like "arkose:token_verification:success:{BUCKET_ID_HERE}"
      def bucket_counter_key(prefix, at: Time.zone.now)
        "#{prefix}#{bucket_id(at: at)}"
      end

      # NOTE: A bucket id is comprise of the current date and the number of the bucket.
      # E.g. 00:00-03:59 bucket will have bucket id 20240612-0, 04:00-07:59 20240612-1 and so on.
      def bucket_id(at: Time.zone.now)
        date_str     = at.strftime('%Y%m%d')
        bucket_index = at.hour / BUCKET_DURATION_HOURS
        "#{date_str}-#{bucket_index}"
      end

      def with_redis
        ::Gitlab::Redis::SharedState.with { |r| yield r }
      end
    end
  end
end
