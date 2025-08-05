# frozen_string_literal: true

module Security
  module SecretDetection
    class PartnerTokenVerificationWorker
      include ApplicationWorker
      include Gitlab::Utils::StrongMemoize

      # Retryable exceptions - network and temporary errors that make sense to retry
      RETRYABLE_EXCEPTIONS = [Gitlab::HTTP::HTTP_TIMEOUT_ERRORS, EOFError, SocketError, OpenSSL::SSL::SSLError,
        OpenSSL::OpenSSLError, Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH,
        Errno::ETIMEDOUT, Net::ReadTimeout, Net::OpenTimeout, Timeout::Error].flatten.freeze

      data_consistency :sticky
      feature_category :secret_detection
      urgency :low
      defer_on_database_health_signal :gitlab_main
      concurrency_limit -> { 250 }
      idempotent!

      # Control retry behavior through sidekiq_retry_in
      sidekiq_retry_in do |count, exception|
        # Only retry up to 3 times for retryable exceptions
        if count < 3 && retryable_exception_class?(exception.class)
          # Exponential backoff: 4, 16, 64 seconds
          4**count
        else
          # For non-retryable exceptions or after 3 retries, don't retry
          false
        end
      end

      def self.retryable_exception_class?(exception_class)
        return false unless exception_class

        RETRYABLE_EXCEPTIONS.include?(exception_class)
      end

      def perform(finding_id, user_id)
        @finding_id = finding_id
        @user_id = user_id

        return log_and_return('Finding not found') unless finding
        return log_and_return('User not found') unless user

        result = ::Security::SecretDetection::TokenVerificationRequestService
                   .new(user, finding)
                   .execute

        log_result(result)

        # Re-raise retryable exceptions for Sidekiq to handle
        handle_service_errors(result) unless result.success?
      end

      private

      attr_reader :finding_id, :user_id

      def finding
        Vulnerabilities::Finding.with_project.find_by_id(finding_id)
      end
      strong_memoize_attr :finding

      def user
        User.find_by_id(user_id)
      end
      strong_memoize_attr :user

      def log_result(result)
        if result.success?
          log_extra_metadata_on_done(:status, 'success')
          log_extra_metadata_on_done(:finding_id, result.payload[:finding_id])
          log_extra_metadata_on_done(:request_id, result.payload[:request_id]) if result.payload[:request_id]
        else
          log_extra_metadata_on_done(:status, 'error')
          log_extra_metadata_on_done(:error_message, result.message)
          log_extra_metadata_on_done(:error_type, result.payload[:error_type])
        end
      end

      def handle_service_errors(result)
        error_type = result.payload[:error_type]

        # Only retry when send_verification_request fails with retryable network exceptions
        raise StandardError, result.message if self.class.retryable_exception_class?(error_type)

        # For all other error types (configuration, authorization, validation, etc.)
        # don't retry as they won't be resolved by retrying
        log_extra_metadata_on_done(:retry_decision, 'not_retryable')
      end

      def log_and_return(message)
        log_extra_metadata_on_done(:status, 'skipped')
        log_extra_metadata_on_done(:reason, message)

        Gitlab::AppLogger.info(
          message: message,
          worker_class: self.class.name,
          finding_id: finding_id,
          user_id: user_id
        )
      end
    end
  end
end
