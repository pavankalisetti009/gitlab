# frozen_string_literal: true

module Users
  module CompromisedPasswords
    class DetectAndNotifyService
      def initialize(current_user, request_password, request)
        @user = current_user
        @request_password = request_password
        @request = request
      end

      def execute
        return unless request_contains_valid_compromised_password? && user_needs_notification?

        return unless create_detection?

        increment_metric
      end

      private

      attr_reader :user, :request_password, :request

      def request_contains_valid_compromised_password?
        return false unless user.valid_password?(request_password)

        ::Gitlab::Auth::CloudflareExposedCredentialChecker.new(request).exact_password?
      end

      def user_needs_notification?
        return false unless ::Feature.enabled?(:notify_compromised_passwords, user)
        return false unless ::Gitlab::Saas.feature_available?(:notify_compromised_passwords)
        return false if user.password_based_omniauth_user?
        return false if user.access_locked?

        true
      end

      def increment_metric
        Gitlab::Metrics
          .counter(
            :compromised_password_detection_notifications_sent,
            'Counter of compromised password detection notifications sent'
          )
          .increment
      end

      def create_detection?
        return if user.compromised_password_detections.unresolved.exists?

        detection = user.compromised_password_detections.create

        return true if detection.persisted?

        Gitlab::AppLogger.error(
          message: "Failed to create CompromisedPasswordDetection",
          errors: detection.errors.full_messages,
          user_id: user.id
        )

        false
      end
    end
  end
end
