# frozen_string_literal: true

module Security
  module SecretDetection
    class TokenVerificationRequestService < ::BaseService
      include Gitlab::Utils::StrongMemoize

      SDRS_ENDPOINT = '/api/v1/token/verify'

      attr_reader :finding, :current_user

      delegate :project, :token_type, :token_value, to: :finding, private: true

      def initialize(current_user, finding)
        @finding = finding
        @current_user = current_user
      end

      def execute
        return error('Feature is disabled') unless feature_enabled?
        return error('Unauthorized') unless can_verify_token?
        return error('SDRS not configured') unless sdrs_configured?
        return error('Invalid finding') unless valid_finding?

        update_token_status!('unknown')

        jwt_token = generate_jwt_token
        return error('Failed to generate JWT') unless jwt_token

        response = send_verification_request(jwt_token)
        return response if response.error?

        handle_sdrs_response(response.payload[:http_response])
      rescue StandardError => e
        handle_unexpected_error(e)
      end

      private

      def can_verify_token?
        can?(current_user, :read_vulnerability, project)
      end

      def feature_enabled?
        project.present? && project.licensed_feature_available?(:secret_detection) &&
          Feature.enabled?(:secret_detection_sdrs_token_verification_flow, project)
      end

      def sdrs_configured?
        ::Gitlab::CurrentSettings.sdrs_enabled && sdrs_url.present?
      end

      def valid_finding?
        finding.secret_detection? && token_value.present? && token_type.present?
      end

      def generate_jwt_token
        ::Authz::SdrsAuthenticationService.generate_token(
          user: current_user,
          project: project,
          finding_id: finding.id
        )
      rescue ::Authz::SdrsAuthenticationService::SigningKeyNotConfigured => e
        log_error("JWT signing key not configured", e)
        nil
      rescue StandardError => e
        log_error("Failed to generate JWT token", e)
        nil
      end

      def send_verification_request(jwt_token)
        http_response = Gitlab::HTTP.post(
          request_url,
          headers: request_headers(jwt_token),
          body: request_body.to_json
        )
        success(http_response: http_response)
      rescue StandardError => e
        log_error("Unexpected error during SDRS request", e)
        error("Unexpected error during SDRS request: #{e.message}", e.class)
      end

      def handle_sdrs_response(response)
        return error('No response received') unless response

        if response.code == 202
          log_info("Token verification request accepted by SDRS")
          success(finding_id: finding.id, request_id: request_id)
        else
          log_error("Unexpected SDRS response", nil, response_code: response.code)
          error('Unexpected SDRS response', :unexpected_sdrs_response)
        end
      end

      def handle_unexpected_error(exception)
        Gitlab::ErrorTracking.track_and_raise_for_dev_exception(
          exception,
          finding_id: finding.id,
          user_id: current_user.id,
          project_id: project.id,
          token_type: token_type
        )

        error(exception.message, :internal_error)
      end

      def update_token_status!(status)
        token_status = finding.finding_token_status
        token_status.update!(status: status)
      end

      def request_url
        "#{sdrs_url}#{SDRS_ENDPOINT}"
      end

      def request_headers(jwt_token)
        {
          'Authorization' => "Bearer #{jwt_token}",
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'X-Request-ID' => request_id
        }
      end

      def request_body
        {
          token_type: token_type,
          token_value: token_value,
          finding_id: finding.id,
          callback_url: callback_url
        }
      end

      def callback_url
        # TODO: Change this to Gitlab::Routing.url_helpers.api_v4_internal_token_status_callback_url
        # once https://gitlab.com/gitlab-org/gitlab/-/issues/551363 is done
        "#{Gitlab.config.gitlab.url}/api/v4/internal/token_status/callback"
      end
      strong_memoize_attr :callback_url

      def sdrs_url
        ::Gitlab::CurrentSettings.sdrs_url
      end
      strong_memoize_attr :sdrs_url

      def request_id
        @request_id ||= SecureRandom.uuid
      end

      def log_info(message, context = {})
        Gitlab::AppLogger.info(structured_logging_payload(message, context))
      end

      def log_error(message, exception = nil, context = {})
        payload = structured_logging_payload(message, context)
        payload[:exception] = exception.class.name if exception
        payload[:exception_message] = exception.message if exception
        payload[:exception_backtrace] = Gitlab::BacktraceCleaner.clean_backtrace(exception.backtrace) if exception

        Gitlab::AppLogger.error(payload)
      end

      def structured_logging_payload(message, context = {})
        {
          message: message,
          service_class: self.class.name,
          finding_id: finding.id,
          project_id: project.id,
          project_path: project.full_path,
          user_id: current_user.id,
          username: current_user.username,
          token_type: token_type,
          request_id: request_id,
          feature_flag_enabled: feature_enabled?
        }.merge(context)
      end

      def error(message, type = nil)
        ServiceResponse.error(message: message, payload: { error_type: type })
      end

      def success(payload)
        ServiceResponse.success(payload: payload)
      end
    end
  end
end
