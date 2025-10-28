# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::PipelineJwt, feature_category: :secrets_management do
  let_it_be(:project) { create(:project, :repository) }
  let(:build) { create(:ci_build, project: project) }
  let(:rsa_key) { OpenSSL::PKey::RSA.generate(3072) }

  before do
    stub_application_setting(ci_jwt_signing_key: rsa_key.to_pem)
  end

  describe '.for_build' do
    it 'includes secrets_manager_scope="pipeline" in the payload' do
      token = described_class.for_build(build, aud: 'https://secrets.example')
      payload, = ::JWT.decode(token, nil, false) # inspect claims only

      expect(payload['secrets_manager_scope']).to eq('pipeline')
    end
  end
end
