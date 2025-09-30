# frozen_string_literal: true

module Security
  module SecretDetection
    class PartnerTokensClient
      include Gitlab::Utils::StrongMemoize

      delegate :project, :token_type, :token_value, to: :finding, allow_nil: true
      attr_reader :finding

      def initialize(finding)
        @finding = finding
      end

      def rate_limited?
        ::Gitlab::ApplicationRateLimiter.throttled?(
          partner_config[:rate_limit_key],
          scope: [project]
        )
      end

      def valid_config?
        !!(partner_config && token_type && token_value)
      end

      def verify_token
        PartnerTokens::Registry.client_for(token_type).verify_token(token_value)
      end

      def partner_config
        PartnerTokens::Registry.partner_for(token_type)
      end
      strong_memoize_attr :partner_config
    end
  end
end
