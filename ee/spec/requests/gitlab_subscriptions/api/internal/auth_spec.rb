# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::API::Internal::Auth, :aggregate_failures, :api, feature_category: :plan_provisioning do
  describe '.verify_api_request' do
    let_it_be(:internal_api_jwk) { ::JWT::JWK.new(OpenSSL::PKey.generate_key('RSA')) }
    let_it_be(:unrelated_jwk) { ::JWT::JWK.new(OpenSSL::PKey.generate_key('RSA')) }

    context 'when the request does not have the internal token header' do
      it 'returns nil' do
        headers = { 'Other-Header' => 'test-token' }

        expect(described_class.verify_api_request(headers)).to be_nil
      end
    end

    context 'when the open ID configuration cannot be fetched' do
      it 'returns nil' do
        stub_open_id_configuration(success: false, json: {})

        token = generate_token(jwk: internal_api_jwk, payload: jwt_payload)

        expect(described_class.verify_api_request({ 'X-Customers-Dot-Internal-Token' => token })).to be_nil
      end
    end

    context 'when the JWKS cannot be fetched' do
      it 'returns nil' do
        stub_open_id_configuration
        stub_keys_discovery(success: false)

        token = generate_token(jwk: internal_api_jwk, payload: jwt_payload)

        expect(described_class.verify_api_request({ 'X-Customers-Dot-Internal-Token' => token })).to be_nil
      end
    end

    context 'when the JWKs can be fetched from the subscription portal', :freeze_time do
      before do
        stub_open_id_configuration
        stub_keys_discovery(jwks: [unrelated_jwk, internal_api_jwk])
      end

      context 'when the token has the wrong issuer' do
        it 'returns nil' do
          token = generate_token(
            jwk: internal_api_jwk,
            payload: jwt_payload(iss: 'some-other-issuer')
          )

          expect(described_class.verify_api_request({ 'X-Customers-Dot-Internal-Token' => token })).to be_nil
        end
      end

      context 'when the token has the wrong subject' do
        it 'returns nil' do
          token = generate_token(
            jwk: internal_api_jwk,
            payload: jwt_payload(sub: 'some-other-subject')
          )

          expect(described_class.verify_api_request({ 'X-Customers-Dot-Internal-Token' => token })).to be_nil
        end
      end

      context 'when the token has the wrong audience' do
        it 'returns nil' do
          token = generate_token(
            jwk: internal_api_jwk,
            payload: jwt_payload(aud: 'some-other-audience')
          )

          expect(described_class.verify_api_request({ 'X-Customers-Dot-Internal-Token' => token })).to be_nil
        end
      end

      context 'when the token has expired' do
        it 'returns nil' do
          token = generate_token(
            jwk: internal_api_jwk,
            payload: jwt_payload(iat: 10.minutes.ago.to_i, exp: 5.minutes.ago.to_i)
          )

          expect(described_class.verify_api_request({ 'X-Customers-Dot-Internal-Token' => token })).to be_nil
        end
      end

      context 'when the token cannot be decoded using the CustomersDot JWKs' do
        it 'returns nil' do
          token = generate_token(
            jwk: ::JWT::JWK.new(OpenSSL::PKey.generate_key('RSA')),
            payload: jwt_payload
          )

          expect(described_class.verify_api_request({ 'X-Customers-Dot-Internal-Token' => token })).to be_nil
        end
      end

      context 'when the token can be decoded using CustomersDot JWKs' do
        it 'returns the decoded JWT' do
          token = generate_token(jwk: internal_api_jwk, payload: jwt_payload)

          expect(described_class.verify_api_request({ 'X-Customers-Dot-Internal-Token' => token })).to match_array(
            [jwt_payload.stringify_keys, { 'typ' => 'JWT', 'kid' => internal_api_jwk.kid, 'alg' => 'RS256' }]
          )
        end
      end
    end

    def generate_token(jwk:, payload:)
      JWT.encode(payload, jwk.keypair, 'RS256', { typ: 'JWT', kid: jwk.kid })
    end

    def jwt_payload(**options)
      {
        aud: 'gitlab-subscriptions',
        sub: 'customers-dot-internal-api',
        iss: "#{Gitlab::Routing.url_helpers.subscription_portal_url}/",
        exp: (Time.current.to_i + 5.minutes.to_i)
      }.merge(options)
    end

    def stub_open_id_configuration(success: true, json: nil)
      subscriptions_host = Gitlab::Routing.url_helpers.subscription_portal_url
      response_json = json || {
        'issuer' => "#{subscriptions_host}/",
        'jwks_uri' => "#{subscriptions_host}/oauth/discovery/keys",
        'id_token_signing_alg_values_supported' => ['RS256']
      }

      gitlab_http_response = instance_double(HTTParty::Response, ok?: success, parsed_response: response_json)

      allow(Gitlab::HTTP)
        .to receive(:get)
        .with("#{subscriptions_host}/.well-known/openid-configuration")
        .and_return(gitlab_http_response)
    end

    def stub_keys_discovery(success: true, jwks: [])
      response_json = {
        'keys' => jwks.map { |jwk| jwk.export.merge('use' => 'sig', 'alg' => 'RS256') }
      }

      gitlab_http_response = instance_double(HTTParty::Response, ok?: success, parsed_response: response_json)

      allow(Gitlab::HTTP)
        .to receive(:get)
        .with("#{Gitlab::Routing.url_helpers.subscription_portal_url}/oauth/discovery/keys")
        .and_return(gitlab_http_response)
    end
  end
end
