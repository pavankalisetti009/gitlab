# frozen_string_literal: true

# rubocop:disable Gitlab/BoundedContexts -- https://gitlab.com/gitlab-org/modelops/anti-abuse/team-tasks/-/issues/809
module Arkose
  class BaseService
    ARKOSE_LABS_DEFAULT_NAMESPACE = 'client'
    ARKOSE_LABS_DEFAULT_SUBDOMAIN = 'verify-api'
    Error = Class.new(StandardError)

    attr_reader :user, :email, :session_token

    def initialize(session_token:, user: nil, email: nil)
      @session_token = session_token
      @user = user
      @email = email
    end

    private

    def arkose_verify
      response = http_post(arkose_verify_url, verify_body)

      ::Arkose::VerifyResponse.new(response.parsed_response)
    end

    def arkose_verify_url
      arkose_labs_namespace = ::Gitlab::CurrentSettings.arkose_labs_namespace
      subdomain = if arkose_labs_namespace == ARKOSE_LABS_DEFAULT_NAMESPACE
                    ARKOSE_LABS_DEFAULT_SUBDOMAIN
                  else
                    "#{arkose_labs_namespace}-verify"
                  end

      "https://#{subdomain}.arkoselabs.com/api/v4/verify/"
    end

    def verify_body
      {
        private_key: Settings.arkose_private_api_key,
        session_token: session_token,
        log_data: user&.id,
        email_address: user&.email || email
      }.compact
    end

    def http_post(url, body)
      response = Gitlab::HTTP.perform_request(
        Net::HTTP::Post,
        url,
        body: body.to_json,
        format: :json,
        headers: { 'Content-Type' => 'application/json' }
      )

      client_error!(response) unless response.code == HTTP::Status::OK

      response
    end

    def client_error!(response)
      raise Error, "Arkose API call failed with status code: #{response.code}, response: #{response.body}"
    end
  end
end
# rubocop:enable Gitlab/BoundedContexts
