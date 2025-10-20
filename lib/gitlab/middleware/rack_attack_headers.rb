# frozen_string_literal: true

# This Rack middleware adds rate limit headers to all responses that have
# been processed by Rack::Attack, not just throttled requests.
#
# This allows clients to proactively adjust their request rates before hitting
# rate limits, improving the overall user experience.
#
# Related issue: https://gitlab.com/gitlab-com/gl-infra/production-engineering/-/issues/25372

module Gitlab
  module Middleware
    class RackAttackHeaders
      # RackAttack stores information on applicable throttles in the Rack env using this key
      RACK_ATTACK_THROTTLE_DATA_KEY = 'rack.attack.throttle_data'

      def initialize(app)
        @app = app
      end

      def call(env)
        status, headers, body = @app.call(env)

        return [status, headers, body] unless feature_enabled?

        # Add rate limit headers if Rack::Attack has throttle data
        if should_add_headers?(env, status)
          rate_limit_headers = generate_headers(env)
          headers.merge!(rate_limit_headers) if rate_limit_headers.present?
        end

        [status, headers, body]
      end

      private

      def feature_enabled?
        Feature.enabled?(
          :rate_limiting_headers_for_unthrottled_requests,
          Feature.current_request
        )
      end

      def should_add_headers?(env, status)
        # Skip if already throttled (headers already added by throttled_responder, see Gitlab::RackAttack)
        return false if status == 429

        # Skip if no throttle data available
        return false unless env[RACK_ATTACK_THROTTLE_DATA_KEY].present?

        true
      end

      def generate_headers(env)
        active_throttles = env[RACK_ATTACK_THROTTLE_DATA_KEY]

        return unless active_throttles.is_a?(Hash) && active_throttles.present?

        # Rack attack populates active_throttles as a hash:
        # structure: {'throttle_name' => {discriminator, count, period, limit, epoch_time}}
        # See https://github.com/rack/rack-attack/blob/427fdfabbc4b6283af14b6916dec4d2d4074e9e4/lib/rack/attack/throttle.rb#L41

        # Find the throttle with the lowest remaining request count
        name, data = find_most_restrictive_throttle(active_throttles)

        throttle_data = Gitlab::RackAttack::RequestThrottleData.from_rack_attack(name, data)

        return unless throttle_data

        throttle_data.common_response_headers
      end

      def find_most_restrictive_throttle(throttles)
        # Select the throttle with the lowest remaining count
        # remaining = limit - count
        throttles.min_by do |_, data|
          limit = data[:limit] || 0
          count = data[:count] || 0
          limit - count
        end
      end
    end
  end
end
