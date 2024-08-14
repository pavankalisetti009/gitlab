# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ai::DuoWorkflows::Workflows, feature_category: :duo_workflow do
  include HttpBasicAuthHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, maintainer_of: project) }
  let(:workflow) { create(:duo_workflows_workflow, user: user, project: project) }
  let(:workflow_service_url) { 'https://duo-workflow-service.example.com' }

  describe 'POST /ai/duo_workflows/workflows' do
    let(:path) { "/ai/duo_workflows/workflows" }
    let(:params) { { project_id: project.id } }

    it 'creates the Ai::DuoWorkflows::Workflow' do
      expect do
        post api(path, user), params: params
        expect(response).to have_gitlab_http_status(:created)
      end.to change { Ai::DuoWorkflows::Workflow.count }.by(1)

      expect(json_response['id']).to eq(Ai::DuoWorkflows::Workflow.last.id)
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
  end

  describe 'GET /ai/duo_workflows/workflows/:id' do
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}" }

    it 'returns the Ai::DuoWorkflows::Workflow' do
      get api(path, user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['id']).to eq(workflow.id)
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
      stub_env('DUO_WORKFLOW_SERVICE_URL', workflow_service_url)
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
        expect(Gitlab::CloudConnector).to receive(:headers).with(user).and_return({ header_key: 'header_value' })
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
        expect(json_response['duo_workflow_service']['base_url']).to eq(workflow_service_url)
        expect(json_response['duo_workflow_service']['token']).to eq('duo_workflow_token')
        expect(json_response['duo_workflow_service']['headers']['header_key']).to eq("header_value")
      end
    end
  end
end
