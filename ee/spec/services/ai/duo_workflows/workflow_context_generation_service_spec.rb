# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::WorkflowContextGenerationService, :aggregate_failures, feature_category: :workflow_catalog do
  let_it_be(:user) { create(:user) }
  let_it_be(:container) { create(:project) }
  let(:workflow_definition) { 'software_development' }
  let(:service) do
    described_class.new(
      current_user: user,
      organization: container.organization,
      workflow_definition: workflow_definition,
      container: container
    )
  end

  describe '#generate_oauth_token' do
    let(:oauth_service) { instance_double(Ai::DuoWorkflows::CreateOauthAccessTokenService) }
    let(:oauth_token) { instance_double(OauthAccessToken) }

    before do
      allow(Ai::DuoWorkflows::CreateOauthAccessTokenService).to receive(:new).and_return(oauth_service)
    end

    context 'when token creation succeeds' do
      before do
        allow(oauth_service).to receive(:execute).and_return(
          ServiceResponse.success(payload: { oauth_access_token: oauth_token })
        )
      end

      it 'returns success with oauth access token' do
        result = service.generate_oauth_token

        expect(result).to be_success
        expect(result.payload[:oauth_access_token]).to eq(oauth_token)
      end
    end

    context 'when token creation fails' do
      before do
        allow(oauth_service).to receive(:execute).and_return(
          ServiceResponse.error(message: 'Token creation failed')
        )
      end

      it 'returns error with message and http status' do
        result = service.generate_oauth_token

        expect(result).to be_error
        expect(result.message).to eq('Token creation failed')
      end
    end
  end

  describe '#generate_composite_oauth_token' do
    let(:composite_oauth_service) { instance_double(Ai::DuoWorkflows::CreateCompositeOauthAccessTokenService) }
    let(:oauth_token) { instance_double(OauthAccessToken) }

    before do
      allow(Ai::DuoWorkflows::CreateCompositeOauthAccessTokenService).to receive(:new)
        .and_return(composite_oauth_service)
    end

    context 'when token creation succeeds' do
      before do
        allow(composite_oauth_service).to receive(:execute).and_return(
          ServiceResponse.success(payload: { oauth_access_token: oauth_token })
        )
      end

      it 'returns success with oauth access token' do
        result = service.generate_composite_oauth_token

        expect(result).to be_success
        expect(result.payload[:oauth_access_token]).to eq(oauth_token)
      end
    end

    context 'when token creation fails' do
      before do
        allow(composite_oauth_service).to receive(:execute).and_return(
          ServiceResponse.error(message: 'Composite token creation failed')
        )
      end

      it 'returns error with message' do
        result = service.generate_composite_oauth_token

        expect(result).to be_error
        expect(result.message).to eq('Composite token creation failed')
      end
    end
  end

  describe '#generate_workflow_token' do
    let(:workflow_client) { instance_double(Ai::DuoWorkflow::DuoWorkflowService::Client) }
    let(:token_data) { { token: 'workflow_token', expires_at: 1.hour.from_now } }

    before do
      allow(Ai::DuoWorkflow::DuoWorkflowService::Client).to receive(:new).and_return(workflow_client)
    end

    context 'when token generation succeeds' do
      before do
        allow(workflow_client).to receive(:generate_token).and_return(
          ServiceResponse.success(payload: token_data)
        )
      end

      it 'returns success with token data' do
        result = service.generate_workflow_token

        expect(result).to be_success
        expect(result.payload).to include(token_data)
      end
    end

    context 'when token generation fails' do
      before do
        allow(workflow_client).to receive(:generate_token).and_return(
          ServiceResponse.error(message: 'Workflow token generation failed')
        )
      end

      it 'returns error with message' do
        result = service.generate_workflow_token

        expect(result).to be_error
        expect(result.message).to eq('Workflow token generation failed')
      end
    end
  end

  describe '#generate_oauth_token_with_composite_identity_support' do
    context 'when composite identity feature is enabled' do
      it 'calls generate_composite_oauth_token' do
        expect(service).to receive(:generate_composite_oauth_token)

        service.generate_oauth_token_with_composite_identity_support
      end
    end

    context 'when composite identity feature is disabled' do
      before do
        stub_feature_flags(duo_workflow_use_composite_identity: false)
      end

      it 'calls generate_oauth_token' do
        expect(service).to receive(:generate_oauth_token)

        service.generate_oauth_token_with_composite_identity_support
      end
    end
  end

  describe '#use_service_account?' do
    context 'when composite identity feature is enabled' do
      it 'returns true' do
        expect(service.use_service_account?).to be(true)
      end
    end

    context 'when composite identity feature is disabled' do
      before do
        stub_feature_flags(duo_workflow_use_composite_identity: false)
      end

      it 'returns false' do
        expect(service.use_service_account?).to be(false)
      end
    end
  end
end
