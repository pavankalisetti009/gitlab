# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::SdrsAuthenticationService, feature_category: :secret_detection do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let(:finding_id) { 123 }
  let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }

  describe '.generate_token' do
    subject(:token) { described_class.generate_token(user: user, project: project, finding_id: finding_id) }

    context 'when signing key is configured' do
      before do
        stub_application_setting(sdrs_jwt_signing_key: rsa_key.to_pem)
      end

      it 'includes correct claims', :freeze_time do
        allow(SecureRandom).to receive(:uuid).and_return('test-uuid-12345')
        decoded = JWT.decode(token, rsa_key.public_key, true, algorithm: 'RS256')
        claims = decoded.first

        expect(claims).to match(
          'iss' => 'gitlab-secret-detection',
          'aud' => 'sdrs',
          'sub' => "user:#{user.id}",
          'exp' => 1.hour.from_now.to_i,
          'iat' => Time.current.to_i,
          'jti' => 'test-uuid-12345',
          'gitlab' => {
            'user_id' => user.id,
            'project_id' => project.id,
            'finding_id' => finding_id,
            'service' => 'token-verification',
            'scopes' => ['token:verify']
          }
        )
      end

      it 'generates unique JTI for each token' do
        token1 = described_class.generate_token(user: user, project: project, finding_id: finding_id)
        token2 = described_class.generate_token(user: user, project: project, finding_id: finding_id)

        jti1 = JWT.decode(token1, rsa_key.public_key, false).first['jti']
        jti2 = JWT.decode(token2, rsa_key.public_key, false).first['jti']

        expect(jti1).not_to eq(jti2)
      end
    end

    context 'when signing key is not configured' do
      before do
        stub_application_setting(sdrs_jwt_signing_key: nil)
      end

      it 'raises SigningKeyNotConfigured error' do
        expect { token }.to raise_error(
          described_class::SigningKeyNotConfigured,
          'SDRS JWT signing key not configured'
        )
      end
    end

    context 'when signing key is invalid' do
      before do
        stub_application_setting(sdrs_jwt_signing_key: 'invalid-key')
      end

      it 'raises an OpenSSL error' do
        expect { token }.to raise_error(OpenSSL::PKey::RSAError)
      end
    end
  end
end
