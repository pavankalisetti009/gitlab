# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ExecuteWorkflowService, :aggregate_failures, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, organization: organization, developers: user) }
  let_it_be(:item) { create(:ai_catalog_item, project:) }
  let_it_be(:item_version) { item.versions.last.tap { |version| version.update!(release_date: 1.hour.ago) } }

  let(:json_config) do
    {
      'version' => 'experimental',
      'environment' => 'remote',
      'components' => [],
      'routers' => [],
      'flow' => []
    }
  end

  let(:goal) { 'Write a Ruby program that prints "Hello, World!"' }
  let(:container) { project }
  let(:params) do
    {
      json_config: json_config,
      container: container,
      goal: goal,
      item_version: item_version
    }
  end

  let(:service) { described_class.new(user, params) }

  before do
    enable_ai_catalog
  end

  shared_examples "returns error response" do |expected_message|
    it "returns an error service response" do
      response = service.execute

      expect(response).to be_error
      expect(response.message).to match_array(expected_message)
    end
  end

  context 'when json_config is missing' do
    let(:json_config) { nil }

    it_behaves_like 'returns error response', 'JSON config is required'
  end

  context 'when current_user is missing' do
    let(:user) { nil }

    it_behaves_like 'returns error response', 'You have insufficient permissions'
  end

  context 'when container is missing' do
    let(:container) { nil }

    it_behaves_like 'returns error response', 'container must be a Project or Namespace'
  end

  context 'when goal is missing' do
    let(:goal) { nil }

    it_behaves_like 'returns error response', 'Goal is required'

    context 'when goal is empty string' do
      let(:goal) { '' }

      it_behaves_like 'returns error response', 'Goal is required'
    end
  end

  context 'when the workflow catalog feature flag is disabled' do
    before do
      stub_feature_flags(global_ai_catalog: false)
    end

    it_behaves_like 'returns error response', 'You have insufficient permissions'
  end

  context 'with a container where the user is not a developer' do
    let(:user) { create(:user, reporter_of: project) }

    it_behaves_like 'returns error response', 'You have insufficient permissions'
  end

  context 'when validation passes' do
    let(:create_workflow_service) { instance_double(::Ai::DuoWorkflows::CreateWorkflowService) }
    let(:start_workflow_service) { instance_double(::Ai::DuoWorkflows::StartWorkflowService) }
    let(:oauth_service) { instance_double(::Ai::DuoWorkflows::CreateOauthAccessTokenService) }
    let(:workflow_client) { instance_double(::Ai::DuoWorkflow::DuoWorkflowService::Client) }
    let(:oauth_token) do
      { oauth_access_token: instance_double(Doorkeeper::AccessToken, plaintext_token: 'token-12345') }
    end

    let(:workflow_service_token) do
      { token: 'workflow_token', expires_at: 1.hour.from_now }
    end

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      allow(user).to receive(:allowed_to_use?).and_return(true)
      project.project_setting.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)

      allow_next_instance_of(::Ai::DuoWorkflows::WorkflowContextGenerationService) do |service|
        allow(service).to receive_messages(
          generate_oauth_token_with_composite_identity_support:
            ServiceResponse.success(payload: oauth_token),
          generate_workflow_token:
            ServiceResponse.success(payload: workflow_service_token),
          use_service_account?: false
        )
      end
    end

    shared_examples 'skips workflow execution' do
      it_behaves_like 'prevents CI pipeline creation for Duo Workflow' do
        subject { service.execute }
      end

      it 'returns an error response' do
        response = service.execute

        expect(response).to be_error
        expect(response[:workflow]).to be_nil
        expect(response[:workload_id]).to be_nil
      end
    end

    shared_examples 'starts workflow execution' do
      it_behaves_like 'creates CI pipeline for Duo Workflow execution' do
        subject { service.execute }
      end

      it 'returns a success response' do
        response = service.execute

        expect(response).to be_success
        expect(response[:workflow]).to eq(Ai::DuoWorkflows::Workflow.last)
        expect(response[:workload_id]).to eq(Ci::Workloads::Workload.last.id)
        expect(response[:flow_config]).to eq(json_config.to_yaml)
      end
    end

    context 'when workflow creation fails' do
      before do
        allow(::Ai::DuoWorkflows::CreateWorkflowService).to receive(:new).and_return(create_workflow_service)
        allow(create_workflow_service).to receive(:execute)
          .and_return(ServiceResponse.error(message: 'Workflow creation failed'))
      end

      it_behaves_like 'returns error response', 'Workflow creation failed'
    end

    context 'when workflow creation succeeds' do
      it_behaves_like 'starts workflow execution'

      it 'creates a Ai::DuoWorkflows::Workflow correctly' do
        expect do
          service.execute
        end.to change { Ai::DuoWorkflows::Workflow.count }.by(1)

        workflow_session = Ai::DuoWorkflows::Workflow.last

        expect(workflow_session).to have_attributes(
          goal: goal,
          environment: 'web',
          workflow_definition: 'ai_catalog_agent',
          agent_privileges: described_class::AGENT_PRIVILEGES,
          pre_approved_agent_privileges: described_class::AGENT_PRIVILEGES
        )
      end

      context 'when oauth token creation fails' do
        before do
          allow_next_instance_of(::Ai::DuoWorkflows::WorkflowContextGenerationService) do |service|
            allow(service).to receive(:generate_oauth_token_with_composite_identity_support)
              .and_return(ServiceResponse.error(message: 'OAuth token creation failed'))
          end
        end

        it_behaves_like 'returns error response', 'OAuth token creation failed'
      end

      context 'when workflow token creation fails' do
        before do
          allow_next_instance_of(::Ai::DuoWorkflows::WorkflowContextGenerationService) do |service|
            allow(service).to receive_messages(
              generate_oauth_token_with_composite_identity_support:
                ServiceResponse.success(payload: oauth_token),
              generate_workflow_token:
                ServiceResponse.error(message: 'Workflow token creation failed')
            )
          end
        end

        it_behaves_like 'returns error response', 'Workflow token creation failed'
      end

      context 'when workflow start fails' do
        before do
          allow(::Ai::DuoWorkflows::StartWorkflowService).to receive(:new).and_return(start_workflow_service)
          allow(start_workflow_service).to receive(:execute)
            .and_return(ServiceResponse.error(message: 'Workflow start failed'))
        end

        it_behaves_like 'returns error response', 'Workflow start failed'
      end

      context 'when duo_workflow_in_ci Feature flag is disabled' do
        before do
          stub_feature_flags(duo_workflow_in_ci: false)
        end

        it_behaves_like 'skips workflow execution'
      end

      context 'when duo_remote_flows_enabled settings is turned off' do
        before do
          project.project_setting.update!(duo_remote_flows_enabled: false)
        end

        it_behaves_like 'skips workflow execution'
      end

      context 'when ci pipeline could not be created' do
        let(:pipeline) do
          instance_double(Ci::Pipeline, created_successfully?: false, full_error_messages: 'some errors')
        end

        let(:service_response) { ServiceResponse.error(message: 'Error in creating pipeline', payload: pipeline) }

        before do
          allow_next_instance_of(::Ci::CreatePipelineService) do |instance|
            allow(instance).to receive(:execute).and_return(service_response)
          end
        end

        it_behaves_like 'returns error response', 'Error in creating workload: some errors'
      end
    end
  end
end
