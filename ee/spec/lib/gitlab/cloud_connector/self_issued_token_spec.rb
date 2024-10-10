# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CloudConnector::SelfIssuedToken, feature_category: :cloud_connector do
  let(:extra_claims) { {} }

  subject(:token) do
    described_class.new(
      audience: 'gitlab-ai-gateway', subject: 'ABC-123', scopes: [:code_suggestions], extra_claims: extra_claims
    )
  end

  describe '#payload' do
    subject(:payload) { token.payload }

    it 'has correct values for the standard JWT attributes', :freeze_time, :aggregate_failures do
      now = Time.now.to_i

      expect(payload[:iss]).to eq(Doorkeeper::OpenidConnect.configuration.issuer)
      expect(payload[:aud]).to eq('gitlab-ai-gateway')
      expect(payload[:sub]).to eq('ABC-123')
      expect(payload[:iat]).to eq(now)
      expect(payload[:nbf]).to eq(now - 5.seconds.freeze)
      expect(payload[:exp]).to eq(now + 1.hour.freeze)
    end

    context 'when passing extra claims' do
      let(:extra_claims) { { custom: 123 } }

      it 'includes them in payload' do
        expect(payload[:custom]).to eq(123)
      end
    end
  end

  describe '#encoded' do
    context 'when signing key is present' do
      it 'encodes successfully' do
        expect(token.encoded).to an_instance_of(String)
      end

      it 'decodes successfully with public key', :aggregate_failures do
        jwt = token.encoded
        public_key = token.send(:key).public_key

        payload, headers = JWT.decode(jwt, public_key, true, { algorithm: 'RS256' })

        expect(headers).to eq("alg" => "RS256", "typ" => "JWT")
        expect(payload.keys).to contain_exactly(
          "jti",
          "aud",
          "sub",
          "iss",
          "iat",
          "nbf",
          "exp",
          "gitlab_realm",
          "scopes"
        )
      end
    end

    context 'when signing key is missing' do
      before do
        allow(Rails.application.credentials).to receive(:openid_connect_signing_key).and_return(nil)
      end

      it 'raises NoSigningKeyError' do
        expect { token.encoded }.to raise_error(described_class::NoSigningKeyError)
      end
    end
  end
end
