# frozen_string_literal: true

# rubocop:disable Gitlab/BoundedContexts -- https://gitlab.com/gitlab-org/modelops/anti-abuse/team-tasks/-/issues/809
module Arkose
  class EmailIntelligenceService < BaseService
    # There is no API documentation for this endpoint but the path can be found in the reference architecture.
    # Arkose plans on rolling out a standalone API for email intelligence and this service should be updated
    # when that API is released. https://gitlab.com/gitlab-org/modelops/anti-abuse/team-tasks/-/issues/816
    #
    # https://developer.arkoselabs.com/docs/arkose-on-akamai-reference-architecture
    ARKOSE_LABS_SESSION_TOKEN_URL = 'https://client-api.arkoselabs.com/fc/gt2/public_key'

    def initialize(email:)
      super(session_token: nil, email: email)
    end

    def execute
      @session_token = new_session_token
      response = arkose_verify

      return error(response.error) if response.invalid_token?
      return error(response.email_intelligence_error) if response.email_intelligence_error

      success(response)
    rescue StandardError => error
      Gitlab::ErrorTracking.track_exception(error)

      error(error.message)
    end

    private

    def arkose_session_url
      "#{ARKOSE_LABS_SESSION_TOKEN_URL}/#{Settings.arkose_public_api_key}"
    end

    def new_session_token
      body = { public_key: Settings.arkose_public_api_key }
      response = http_post(arkose_session_url, body)

      raise Error, 'Failed to retrieve Arkose session token' unless response['token']

      response['token']
    end

    def error(error)
      Gitlab::AppLogger.error(
        message: 'Arkose email intelligence failed',
        reason: error,
        session_token: @session_token || '',
        email: email
      )

      ServiceResponse.error(message: error)
    end

    def success(response)
      Gitlab::AppLogger.info(
        message: 'Arkose email intelligence succeeded',
        email: email,
        'arkose.email_intelligence': response.response['email_intelligence']
      )

      ServiceResponse.success(payload: response)
    end
  end
end
# rubocop:enable Gitlab/BoundedContexts
