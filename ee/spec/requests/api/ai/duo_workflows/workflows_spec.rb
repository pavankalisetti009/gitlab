# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ai::DuoWorkflows::Workflows, feature_category: :duo_workflow do
  include HttpBasicAuthHelpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user, maintainer_of: project) }
  let(:workflow) { create(:duo_workflows_workflow, user: user, project: project) }
  let(:duo_workflow_service_url) { 'duo-workflow-service.example.com:50052' }
  let(:oauth_token) { create(:oauth_access_token, user: user, scopes: [:ai_workflows]) }

  describe 'POST /ai/duo_workflows/workflows' do
    let(:path) { "/ai/duo_workflows/workflows" }
    let(:params) { { project_id: project.id } }

    context 'when success' do
      it 'creates the Ai::DuoWorkflows::Workflow' do
        expect do
          post api(path, user), params: params
          expect(response).to have_gitlab_http_status(:created)
        end.to change { Ai::DuoWorkflows::Workflow.count }.by(1)
        expect(json_response['id']).to eq(Ai::DuoWorkflows::Workflow.last.id)
      end

      context 'when authenticated with a token that has the ai_workflows scope' do
        it 'is successful' do
          post api(path, oauth_access_token: oauth_token), params: params

          expect(response).to have_gitlab_http_status(:created)
        end
      end

      context 'with project path params' do
        let(:params) { { project_id: project.full_path } }

        it 'is successful' do
          expect do
            post api(path, user), params: params
            expect(response).to have_gitlab_http_status(:created)
          end.to change { Ai::DuoWorkflows::Workflow.count }.by(1)
          expect(response).to have_gitlab_http_status(:created)
        end
      end
    end

    context 'with a project where the user is not a developer' do
      let(:guest) { create(:user, guest_of: project) }

      it 'is forbidden' do
        post api(path, guest), params: params

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when the duo_workflows feature flag is disabled for the user' do
      before do
        stub_feature_flags(duo_workflow: false)
      end

      it 'is forbidden' do
        post api(path, user), params: params

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when start_workflow is true' do
      let(:params) do
        {
          project_id: project.id,
          start_workflow: true,
          goal: 'Print hello world'
        }
      end

      before do
        allow_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
          allow(client).to receive(:generate_token).and_return({ status: "success", token: "an-encrypted-token" })
        end
      end

      it 'creates a pipeline to run the workflow' do
        expect_next_instance_of(Ci::CreatePipelineService, project, user,
          hash_including(ref: project.default_branch_or_main)
        ) do |pipeline_service|
          expect(pipeline_service).to receive(:execute).and_call_original
        end

        post api(path, user), params: params
        expect(json_response['id']).to eq(Ai::DuoWorkflows::Workflow.last.id)
        expect(json_response['pipeline']).not_to be(nil)
      end

      context 'when ci pipeline could not be created' do
        let(:pipeline) do
          instance_double('Ci::Pipeline', created_successfully?: false, full_error_messages: 'full error messages')
        end

        let(:service_response) { ServiceResponse.error(message: 'Error in creating pipeline', payload: pipeline) }

        before do
          allow_next_instance_of(::Ci::CreatePipelineService) do |instance|
            allow(instance).to receive(:execute).and_return(service_response)
          end
        end

        it 'does not start a pipeline to execute workflow' do
          post api(path, user), params: params
          expect(json_response['id']).to eq(Ai::DuoWorkflows::Workflow.last.id)
          expect(json_response['pipeline']).to be(nil)
        end
      end
    end
  end

  describe 'GET /ai/duo_workflows/workflows/:id' do
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}" }

    it 'returns the Ai::DuoWorkflows::Workflow' do
      get api(path, user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['id']).to eq(workflow.id)
    end

    context 'when authenticated with a token that has the ai_workflows scope' do
      it 'is successful' do
        get api(path, oauth_access_token: oauth_token)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'with a workflow belonging to a different user' do
      let(:workflow) { create(:duo_workflows_workflow) }

      it 'returns 404' do
        get api(path, user)
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'POST /ai/duo_workflows/workflows/:id/checkpoints' do
    let(:current_time) { Time.current }
    let(:thread_ts) { current_time.to_s }
    let(:later_thread_ts) { (current_time + 1.second).to_s }
    let(:parent_ts) { (current_time - 1.second).to_s }
    let(:checkpoint) { { key: 'value' } }
    let(:metadata) { { key: 'value' } }
    let(:params) { { thread_ts: thread_ts, checkpoint: checkpoint, parent_ts: parent_ts, metadata: metadata } }
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/checkpoints" }

    it 'allows creating multiple checkpoints for a workflow' do
      expect do
        post api(path, user), params: params
        expect(response).to have_gitlab_http_status(:created)

        post api(path, user), params: params.merge(thread_ts: later_thread_ts, parent_ts: thread_ts)
        expect(response).to have_gitlab_http_status(:created)
      end.to change { workflow.reload.checkpoints.count }.by(2)

      expect(json_response['id']).to eq(Ai::DuoWorkflows::Checkpoint.last.id)
    end

    context 'when authenticated with a token that has the ai_workflows scope' do
      it 'is successful' do
        post api(path, oauth_access_token: oauth_token),
          params: params.merge(thread_ts: later_thread_ts, parent_ts: thread_ts)

        expect(response).to have_gitlab_http_status(:created)
      end
    end

    it 'fails if the thread_ts is an empty string' do
      post api(path, user), params: params.merge(thread_ts: '')
      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['message']).to include("can't be blank")
    end
  end

  describe 'GET /ai/duo_workflows/workflows/:id/checkpoints' do
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/checkpoints" }

    it 'returns the checkpoints in descending order of thread_ts' do
      checkpoint1 = create(:duo_workflows_checkpoint, project: project)
      checkpoint2 = create(:duo_workflows_checkpoint, project: project)
      workflow.checkpoints << checkpoint1
      workflow.checkpoints << checkpoint2

      get api(path, user)
      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.pluck('id')).to eq([checkpoint2.id, checkpoint1.id])
      expect(json_response.pluck('thread_ts')).to eq([checkpoint2.thread_ts, checkpoint1.thread_ts])
      expect(json_response.pluck('parent_ts')).to eq([checkpoint2.parent_ts, checkpoint1.parent_ts])
      expect(json_response[0]).to have_key('checkpoint')
      expect(json_response[0]).to have_key('metadata')
    end
  end

  describe 'POST /ai/duo_workflows/direct_access' do
    let(:path) { '/ai/duo_workflows/direct_access' }

    before do
      allow(Gitlab.config.duo_workflow).to receive(:service_url).and_return duo_workflow_service_url
      stub_config(duo_workflow: {
        executor_binary_url: 'https://example.com/executor',
        service_url: duo_workflow_service_url,
        executor_version: 'v1.2.3',
        secure: true
      })
    end

    context 'when the duo_workflows feature flag is disabled for the user' do
      before do
        stub_feature_flags(duo_workflow: false)
      end

      it 'returns not found' do
        post api(path, user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when rate limited' do
      it 'returns api error' do
        allow(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?).and_return(true)

        post api(path, user)

        expect(response).to have_gitlab_http_status(:too_many_requests)
      end
    end

    context 'when CreateOauthAccessTokenService returns error' do
      it 'returns api error' do
        expect_next_instance_of(::Ai::DuoWorkflows::CreateOauthAccessTokenService) do |service|
          expect(service).to receive(:execute).and_return({ status: :error, http_status: :forbidden,
message: 'Duo workflow is not enabled for user' })
        end

        post api(path, user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when DuoWorkflowService returns error' do
      it 'returns api error' do
        expect_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
          expect(client).to receive(:generate_token).and_return({ status: :error,
message: "could not generate token" })
        end

        post api(path, user)

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when success' do
      it 'returns access payload' do
        expect(Gitlab::CloudConnector).to receive(:ai_headers).with(user).and_return({ header_key: 'header_value' })
        expect_next_instance_of(::Ai::DuoWorkflows::CreateOauthAccessTokenService) do |service|
          expect(service).to receive(:execute).and_return({ status: :success,
oauth_access_token: instance_double('Doorkeeper::AccessToken', plaintext_token: 'oauth_token') })
        end
        expect_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
          expect(client).to receive(:generate_token).and_return({ status: :success, token: 'duo_workflow_token' })
        end

        post api(path, user)

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['gitlab_rails']['base_url']).to eq(Gitlab.config.gitlab.url)
        expect(json_response['gitlab_rails']['token']).to eq('oauth_token')
        expect(json_response['duo_workflow_service']['base_url']).to eq("duo-workflow-service.example.com:50052")
        expect(json_response['duo_workflow_service']['token']).to eq('duo_workflow_token')
        expect(json_response['duo_workflow_service']['headers']['header_key']).to eq("header_value")
        expect(json_response['duo_workflow_service']['secure']).to eq(Gitlab::DuoWorkflow::Client.secure?)
        expect(json_response['duo_workflow_executor']['executor_binary_url']).to eq('https://example.com/executor')
        expect(json_response['duo_workflow_executor']['version']).to eq('v1.2.3')
      end

      context 'when authenticated with a token that has the ai_workflows scope' do
        it 'succeeds' do
          expect_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
            expect(client).to receive(:generate_token).and_return({ status: :success, token: 'duo_workflow_token' })
          end

          post api(path, oauth_access_token: oauth_token)

          expect(response).to have_gitlab_http_status(:created)
        end
      end
    end
  end

  describe 'POST /ai/duo_workflows/workflows/:id/start' do
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/start" }
    let(:params) do
      {
        workflow_id: workflow.id,
        goal: 'Print hello world'
      }
    end

    before do
      allow_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
        allow(client).to receive(:generate_token).and_return({ status: "success", token: "an-encrypted-token" })
      end
    end

    it 'starts a pipeline to execute the workflow' do
      expect_next_instance_of(Ci::CreatePipelineService, project, user,
        hash_including(ref: project.default_branch_or_main)
      ) do |pipeline_service|
        expect(pipeline_service).to receive(:execute).and_call_original
      end

      post api(path, user), params: params

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['pipeline']).not_to be(nil)
    end

    context 'when it fails to create a CI pipeline' do
      let(:pipeline) do
        instance_double('Ci::Pipeline', created_successfully?: false, full_error_messages: 'validation failed')
      end

      let(:service_response) { ServiceResponse.error(message: 'Error in creating pipeline', payload: pipeline) }

      before do
        allow_next_instance_of(::Ci::CreatePipelineService) do |instance|
          allow(instance).to receive(:execute).and_return(service_response)
        end
      end

      it 'returns api error' do
        post api(path, user), params: params

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['pipeline']).to be(nil)
        expect(json_response['message']).to eq('Pipeline creation failed')
      end
    end
  end
end
