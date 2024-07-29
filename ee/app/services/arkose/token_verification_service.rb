# frozen_string_literal: true

module Arkose
  class TokenVerificationService < BaseService
    def execute
      @response = arkose_verify

      logger.log_successful_token_verification

      return ServiceResponse.error(message: response.error) if response.invalid_token?

      RecordUserDataService.new(response: response, user: user).execute

      if response.allowlisted? || response.challenge_solved?
        payload = {
          low_risk: response.allowlisted? || response.low_risk?,
          response: response
        }
        ServiceResponse.success(payload: payload)
      else
        logger.log_unsolved_challenge
        ServiceResponse.error(message: 'Captcha was not solved')
      end
    rescue StandardError => error
      payload = {
        # Allow user to proceed when we can't verify the token for some
        # unexpected reason (e.g. ArkoseLabs is down)
        low_risk: true,
        session_token: session_token,
        log_data: user&.id
      }.compact

      Gitlab::ExceptionLogFormatter.format!(error, payload)
      Gitlab::ErrorTracking.track_exception(error)

      logger.log_failed_token_verification

      ServiceResponse.success(payload: payload)
    end

    private

    attr_reader :response

    def logger
      @logger ||= ::Arkose::Logger.new(
        session_token: session_token,
        user: user,
        verify_response: response
      )
    end
  end
end
