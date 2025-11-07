# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::WorkflowContextGenerationService, :aggregate_failures, feature_category: :workflow_catalog do
  let_it_be(:user) { create(:user) }
  let_it_be(:container) { create(:project, namespace: create(:group)) }
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

    context 'for duo_workflow_service_url' do
      let(:cloud_connector_url) { 'cloud.staging.gitlab.com:443' }
      let(:self_hosted_url) { 'self-hosted-dap-service-url:50052' }

      before do
        allow(Gitlab::DuoWorkflow::Client).to receive_messages(self_hosted_url: self_hosted_url,
          cloud_connected_url: cloud_connector_url)
        allow(workflow_client).to receive(:generate_token).and_return(
          ServiceResponse.success(payload: { token: 't', expires_at: 1.hour.from_now })
        )
      end

      shared_examples 'initializes client with expected service url' do
        it 'passes expected duo_workflow_service_url to client' do
          expect(Ai::DuoWorkflow::DuoWorkflowService::Client).to receive(:new).with(
            hash_including(
              duo_workflow_service_url: expected_service_server_url,
              current_user: user,
              secure: ::Gitlab::DuoWorkflow::Client.secure?
            )
          ).and_return(workflow_client)

          result = service.generate_workflow_token

          expect(result).to be_success
        end
      end

      context 'when self-hosted feature setting exists' do
        let(:expected_service_server_url) { self_hosted_url }

        let_it_be(:model) do
          create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219')
        end

        let_it_be(:duo_agent_platform_feature_setting) do
          create(:ai_feature_setting, :duo_agent_platform, self_hosted_model: model)
        end

        it_behaves_like 'initializes client with expected service url'
      end

      context 'when instance level model selection exists' do
        let(:expected_service_server_url) { cloud_connector_url }

        let_it_be(:duo_agent_platform_feature_setting) do
          create(:instance_model_selection_feature_setting, feature: :duo_agent_platform)
        end

        it_behaves_like 'initializes client with expected service url'
      end

      context 'when namespace level model selection exists', :saas do
        let(:expected_service_server_url) { cloud_connector_url }

        let_it_be(:duo_agent_platform_feature_setting) do
          create(:ai_namespace_feature_setting,
            namespace: container.namespace,
            feature: :duo_agent_platform,
            offered_model_ref: 'claude_sonnet_3_7_20250219')
        end

        it_behaves_like 'initializes client with expected service url'
      end

      context 'when no feature setting exists' do
        let(:expected_service_server_url) { cloud_connector_url }

        it_behaves_like 'initializes client with expected service url'
      end
    end
  end

  describe '#generate_oauth_token_with_composite_identity_support' do
    before do
      allow(Ai::DuoWorkflow).to receive(:available?).and_return(true)
    end

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

    context 'when Ai::DuoWorkflow is not available' do
      before do
        allow(Ai::DuoWorkflow).to receive(:available?).and_return(false)
      end

      it 'calls generate_oauth_token' do
        expect(service).to receive(:generate_oauth_token)

        service.generate_oauth_token_with_composite_identity_support
      end
    end
  end

  describe '#use_service_account?' do
    before do
      allow(Ai::DuoWorkflow).to receive(:available?).and_return(true)
    end

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

    context 'when Ai::DuoWorkflow is not available' do
      before do
        allow(Ai::DuoWorkflow).to receive(:available?).and_return(false)
      end

      it 'returns false' do
        expect(service.use_service_account?).to be(false)
      end
    end
  end

  describe '#duo_agent_platform_feature_setting' do
    context 'when workflow definition is code_review/v1' do
      let_it_be(:model) do
        create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219')
      end

      let_it_be(:review_merge_request_feature_setting) do
        create(:ai_feature_setting, :review_merge_request, self_hosted_model: model)
      end

      let(:workflow_definition) { 'code_review/v1' }

      it 'returns the review merge request feature setting' do
        expect(service.duo_agent_platform_feature_setting).to eq(review_merge_request_feature_setting)
      end
    end

    context 'when self-hosted feature setting exists' do
      let_it_be(:model) do
        create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219')
      end

      let_it_be(:duo_agent_platform_feature_setting) do
        create(:ai_feature_setting, :duo_agent_platform, self_hosted_model: model)
      end

      it 'returns the self-hosted feature setting' do
        expect(service.duo_agent_platform_feature_setting).to eq(duo_agent_platform_feature_setting)
      end
    end

    context 'when instance level model selection exists' do
      let_it_be(:duo_agent_platform_feature_setting) do
        create(:instance_model_selection_feature_setting, feature: :duo_agent_platform)
      end

      it 'returns the instance level feature setting' do
        expect(service.duo_agent_platform_feature_setting).to eq(duo_agent_platform_feature_setting)
      end
    end

    context 'when namespace level model selection exists', :saas do
      let_it_be(:duo_agent_platform_feature_setting) do
        create(:ai_namespace_feature_setting,
          namespace: container.namespace,
          feature: :duo_agent_platform,
          offered_model_ref: 'claude_sonnet_3_7_20250219')
      end

      it 'returns the namespace level feature setting' do
        expect(service.duo_agent_platform_feature_setting).to eq(duo_agent_platform_feature_setting)
      end
    end
  end
end
