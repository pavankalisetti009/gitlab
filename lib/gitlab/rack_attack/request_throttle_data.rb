# frozen_string_literal: true

module Gitlab
  module RackAttack
    # Class to represent throttle information for a request.
    # This is typically populated from RackAttack data.
    class RequestThrottleData
      attr_reader :name, :period, :limit, :observed, :now

      # Populate the class using data from RackAttack annotations
      # Note: This may return nil if the given arguments don't match expectations
      def self.from_rack_attack(name, data)
        # Match data example:
        # {:discriminator=>"127.0.0.1", :count=>12, :period=>60 seconds, :limit=>1, :epoch_time=>1609833930}
        # Source: https://github.com/rack/rack-attack/blob/v6.3.0/lib/rack/attack/throttle.rb#L33

        return unless name
        return unless %i[count epoch_time period limit].all? { |key| data.key?(key) }

        new(
          name: name.to_s,
          observed: data[:count].to_i,
          now: data[:epoch_time].to_i,
          period: data[:period].to_i,
          limit: data[:limit].to_i
        )
      end

      # Initialize a new RequestThrottleData instance
      #
      # @param name [String] The name of the throttle (e.g. 'throttle_unauthenticated_api')
      # @param period [Integer] The time window in seconds for the throttle
      # @param limit [Integer] The maximum number of requests allowed in the period
      # @param observed [Integer] The current number of requests made in the period
      # @param now [Integer] The current time as a Unix timestamp (epoch time)
      def initialize(name:, period:, limit:, observed:, now:)
        @name = name
        @period = period
        @limit = limit
        @observed = observed
        @now = now
      end

      # Return common response headers for all requests, whether throttled or not
      #
      # Rate Limit HTTP headers are not standardized anywhere. This is the latest draft submitted to IETF:
      # https://github.com/ietf-wg-httpapi/ratelimit-headers/blob/main/draft-ietf-httpapi-ratelimit-headers.md
      #
      # This method implement the most viable parts of the headers.
      # Those headers will be sent back to the client when it gets throttled.
      #
      #   - RateLimit-Limit: indicates the request quota associated to the client in 60 seconds.
      #     The time window for the quota here is supposed to be mirrored to
      #     throttle_*_period_in_seconds application settings.
      #     However, our HAProxy as well as some ecosystem libraries are using a fixed 60-second window.
      #     Therefore, the returned limit is approximately rounded up to fit into that window.
      #
      #   - RateLimit-Observed: indicates the current request amount associated to the client within the time window.
      #
      #   - RateLimit-Remaining: indicates the remaining quota within the time window.
      #     It is the result of RateLimit-Limit - RateLimit-Observed
      #
      #   - RateLimit-Reset: the point of time that the request quota is reset, in Unix time
      #
      def common_response_headers
        {
          'RateLimit-Name' => name.to_s,
          'RateLimit-Limit' => rounded_limit.to_s,
          'RateLimit-Observed' => observed.to_i.to_s,
          'RateLimit-Remaining' => remaining.to_i.to_s,
          'RateLimit-Reset' => reset_time.to_i.to_s
        }
      end

      # When a request is throttled, we add below response headers in addition to headers
      # from .common_response_headers.
      #
      #   - Retry-After: the remaining duration in seconds until the quota is reset.
      #     This is a standardized HTTP header: https://www.rfc-editor.org/rfc/rfc7231#page-69
      #
      #   - RateLimit-ResetTime: the point of time that the request quota is reset, in HTTP date format
      #
      def throttled_response_headers
        # For a throttled request, we additionally indicate when it can be retried the earliest
        common_response_headers.merge(
          {
            'Retry-After' => retry_after.to_s,
            'RateLimit-ResetTime' => reset_time.httpdate
          }
        )
      end

      # The total request quota associated to the client in 60 seconds.
      def rounded_limit
        (limit.to_f * 1.minute / period).ceil
      end

      # The remaining quota within the time window (until reset)
      def remaining
        (limit > observed ? limit - observed : 0)
      end

      # The remaining seconds until the window resets
      def retry_after
        period - (now % period)
      end

      # The time when the window resets
      def reset_time
        Time.at(now + retry_after) # rubocop:disable Rails/TimeZone -- Unix epoch based calculation
      end
    end
  end
end
