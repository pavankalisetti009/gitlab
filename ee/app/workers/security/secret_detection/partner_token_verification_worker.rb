# frozen_string_literal: true

module Security
  module SecretDetection
    class PartnerTokenVerificationWorker
      include ApplicationWorker
      include Gitlab::Utils::StrongMemoize

      data_consistency :sticky
      feature_category :secret_detection
      urgency :low
      idempotent!
      concurrency_limit -> { 250 }
      defer_on_database_health_signal :gitlab_main

      MAX_RATE_LIMIT_RETRIES = 5
      BASE_DELAY = 10.seconds

      def perform(finding_id, finding_type, rate_limit_retry_count = 0)
        return if rate_limit_retry_count >= MAX_RATE_LIMIT_RETRIES

        @finding_type = finding_type.to_sym

        @finding_id = finding_id
        return unless finding

        client = PartnerTokensClient.new(finding)
        return unless client.valid_config?

        if client.rate_limited?
          reschedule(finding_id, finding_type, rate_limit_retry_count + 1)
          return
        end

        result = client.verify_token
        partner_service.save_result(finding, result)
      rescue ::Security::SecretDetection::PartnerTokens::BaseClient::RateLimitError
        reschedule(finding_id, finding_type, rate_limit_retry_count + 1)
        nil
      end

      private

      attr_reader :finding_id, :finding_type

      def finding
        case finding_type
        when :vulnerability then ::Vulnerabilities::Finding.find_by_id(finding_id)
        when :security then ::Security::Finding.find_by_id(finding_id)
        end
      end
      strong_memoize_attr :finding

      def partner_service
        case finding_type
        when :vulnerability then Vulnerabilities::PartnerTokenService.new
        when :security then Security::PartnerTokenService.new
        end
      end

      def reschedule(finding_id, finding_type, retry_count)
        self.class.perform_in(BASE_DELAY, finding_id, finding_type, retry_count)
      end
    end
  end
end
