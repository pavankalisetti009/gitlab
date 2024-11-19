# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CloudConnector::JSONWebToken, feature_category: :cloud_connector do
  let(:extra_claims) { {} }

  let(:expected_issuer) { 'gitlab.com' }
  let(:expected_audience) { 'gitlab-ai-gateway' }
  let(:expected_subject) { 'ABC-123' }
  let(:expected_realm) { 'saas' }
  let(:expected_scopes) { [:code_suggestions] }
  let(:expected_ttl) { 10.minutes }

  subject(:token) do
    described_class.new(
      issuer: expected_issuer,
      audience: expected_audience,
      subject: expected_subject,
      realm: expected_realm,
      scopes: expected_scopes,
      ttl: expected_ttl,
      extra_claims: extra_claims
    )
  end

  describe '#payload' do
    subject(:payload) { token.payload }

    it 'has expected values', :freeze_time, :aggregate_failures do
      now = Time.current.to_i

      # standard claims
      expect(payload[:iss]).to eq(expected_issuer)
      expect(payload[:aud]).to eq(expected_audience)
      expect(payload[:sub]).to eq(expected_subject)
      expect(payload[:iat]).to eq(now)
      expect(payload[:nbf]).to eq(now - 5.seconds)
      expect(payload[:exp]).to eq(now + 10.minutes)

      # cloud connector specific claims
      expect(payload[:gitlab_realm]).to eq(expected_realm)
      expect(payload[:scopes]).to eq(expected_scopes)
    end

    context 'when passing extra claims' do
      let(:extra_claims) { { custom: 123 } }

      it 'includes them in payload' do
        expect(payload[:custom]).to eq(123)
      end
    end
  end

  describe '#encode' do
    let(:rsa_key) { ::JWT::JWK.new(OpenSSL::PKey::RSA.new(2048)) }

    subject(:encoded_token) { token.encode(rsa_key) }

    it 'encodes token instance to string' do
      expect(encoded_token).to be_instance_of(String)
    end

    it 'decodes successfully with public key', :aggregate_failures, :freeze_time do
      now = Time.current.to_i
      payload, header = JWT.decode(encoded_token, rsa_key.public_key, true, { algorithm: 'RS256' })

      expect(header).to match(
        "alg" => "RS256",
        "typ" => "JWT",
        "kid" => be_instance_of(String)
      )
      expect(payload).to match(
        "jti" => be_instance_of(String),
        "aud" => expected_audience,
        "sub" => expected_subject,
        "iss" => expected_issuer,
        "iat" => now.to_i,
        "nbf" => (now - 5.seconds).to_i,
        "exp" => (now + 10.minutes).to_i,
        "gitlab_realm" => expected_realm,
        "scopes" => ["code_suggestions"]
      )
    end
  end
end
