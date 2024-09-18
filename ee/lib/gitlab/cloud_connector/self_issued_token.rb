# frozen_string_literal: true

module Gitlab
  module CloudConnector
    class SelfIssuedToken
      NOT_BEFORE_TIME = 5.seconds.to_i.freeze
      EXPIRES_IN = 1.hour.to_i.freeze

      NoSigningKeyError = Class.new(StandardError)

      attr_reader :issued_at

      def initialize(audience:, subject:, scopes:, extra_claims: {})
        @id = SecureRandom.uuid
        @audience = audience
        @subject = subject
        @issuer = Doorkeeper::OpenidConnect.configuration.issuer
        @issued_at = Time.now.to_i
        @not_before = @issued_at - NOT_BEFORE_TIME
        @expire_time = @issued_at + EXPIRES_IN
        @scopes = scopes
        @extra_claims = extra_claims
      end

      def encoded
        headers = { typ: 'JWT' }

        JWT.encode(payload, key, 'RS256', headers)
      end

      def payload
        {
          jti: @id,
          aud: @audience,
          sub: @subject,
          iss: @issuer,
          iat: @issued_at,
          nbf: @not_before,
          exp: @expire_time
        }.merge(custom_claims)
      end

      private

      def custom_claims
        {
          gitlab_realm: Gitlab::CloudConnector.gitlab_realm,
          scopes: @scopes
        }.merge(@extra_claims)
      end

      def key
        key_data = Rails.application.credentials.openid_connect_signing_key

        raise NoSigningKeyError unless key_data

        OpenSSL::PKey::RSA.new(key_data)
      end
    end
  end
end
