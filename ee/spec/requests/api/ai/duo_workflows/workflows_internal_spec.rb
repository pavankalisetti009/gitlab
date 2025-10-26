# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ai::DuoWorkflows::WorkflowsInternal, :aggregate_failures, feature_category: :duo_agent_platform do
  include HttpBasicAuthHelpers

  let_it_be(:ai_settings) { create(:namespace_ai_settings, duo_workflow_mcp_enabled: true) }
  let_it_be(:group) { create(:group, ai_settings: ai_settings) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:user) { create(:user, maintainer_of: project) }

  let_it_be(:duo_workflow_service_url) { 'duo-workflow-service.example.com:50052' }
  let_it_be(:ai_workflows_oauth_token) { create(:oauth_access_token, user: user, scopes: [:ai_workflows]) }

  let_it_be(:ai_catalog_item_version) { create(:ai_catalog_item_version) }

  let(:workflow) do
    create(
      :duo_workflows_workflow,
      user: user,
      workflow_definition: workflow_definition,
      pre_approved_agent_privileges: [Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES],
      agent_privileges: [Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES],
      ai_catalog_item_version_id: ai_catalog_item_version.id,
      **container_params
    )
  end

  let(:workflow_definition) { 'software_development' }
  let(:container_params) { { project: project } }

  before do
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
    # rubocop:disable RSpec/AnyInstanceOf -- not the next instance
    allow_any_instance_of(User).to receive(:allowed_to_use?).and_return(true)
    # rubocop:enable RSpec/AnyInstanceOf
  end

  describe 'POST /ai/duo_workflows/workflows/:id/checkpoints' do
    let(:current_time) { Time.current }
    let(:thread_ts) { Gitlab::Utils.uuid_v7 }
    let(:later_thread_ts) { Gitlab::Utils.uuid_v7 }
    let(:parent_ts) { Gitlab::Utils.uuid_v7 }
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

      expect(Ai::DuoWorkflows::Checkpoint.distinct.pluck('project_id')).to eq([project.id])

      checkpoint = Ai::DuoWorkflows::Checkpoint.last
      expect(json_response).to eq({
        'id' => checkpoint.id.first,
        'parent_ts' => checkpoint.parent_ts,
        'thread_ts' => checkpoint.thread_ts
      })
    end

    context 'with compressed checkpoint' do
      let(:checkpoint_data) { { 'key' => 'value', 'nested' => { 'data' => 'test' } } }
      let(:compressed_checkpoint) { 'eJyrVspOrVSyUipLzClNVdJRykstLklNUbKqVkpJLEkESpQABZRqawENlQ1i' }
      let(:params) do
        {
          thread_ts: thread_ts,
          compressed_checkpoint: compressed_checkpoint,
          parent_ts: parent_ts,
          metadata: metadata
        }
      end

      it 'successfully creates a checkpoint with compressed data' do
        expect do
          post api(path, user), params: params
          expect(response).to have_gitlab_http_status(:created)
        end.to change { workflow.reload.checkpoints.count }.by(1)

        checkpoint = Ai::DuoWorkflows::Checkpoint.last
        expect(checkpoint.checkpoint).to eq(checkpoint_data)
      end

      context 'with invalid compressed data' do
        let(:compressed_checkpoint) { 'invalid-zlib-base64' }

        it 'fails to create a checkpoint with error' do
          post api(path, user), params: params
          expect(response).to have_gitlab_http_status(:bad_request)
          expect(response.body)
            .to eq({ message: "400 Bad request - Invalid compressed checkpoint data: invalid base64" }.to_json)
        end
      end
    end

    context 'with uncompressed checkpoint' do
      it 'successfully creates a checkpoint with uncompressed data' do
        expect do
          post api(path, user), params: params
          expect(response).to have_gitlab_http_status(:created)
        end.to change { workflow.reload.checkpoints.count }.by(1)

        checkpoint = Ai::DuoWorkflows::Checkpoint.last
        expect(checkpoint.checkpoint).to eq({ 'key' => 'value' })
      end
    end

    context 'with namespace-level chat workflow' do
      let(:workflow_definition) { 'chat' }
      let(:container_params) { { namespace_id: group.id } }

      it 'has correct attributes in checkpoint records' do
        expect(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :agentic_chat).and_return(true)

        post api(path, user), params: params

        expect(response).to have_gitlab_http_status(:created)
        expect(Ai::DuoWorkflows::Checkpoint.distinct.pluck('namespace_id')).to eq([group.id])
      end
    end

    context 'when authenticated with a token that has the ai_workflows scope' do
      it 'is successful' do
        post api(path, oauth_access_token: ai_workflows_oauth_token),
          params: params.merge(thread_ts: later_thread_ts, parent_ts: thread_ts)

        expect(response).to have_gitlab_http_status(:created)
      end

      it "fails when creating a checkpoint for another user's remote execution workflow" do
        other_user = create(:user, maintainer_of: project)
        other_workflow = create(:duo_workflows_workflow, user: other_user, project: project, environment: :web,
          workflow_definition: :convert_to_gitlab_ci)
        checkpoint_path = "/ai/duo_workflows/workflows/#{other_workflow.id}/checkpoints"

        post api(checkpoint_path, oauth_access_token: ai_workflows_oauth_token),
          params: params.merge(thread_ts: later_thread_ts, parent_ts: thread_ts)

        expect(response).to have_gitlab_http_status(:not_found)
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
      checkpoint1 = create(:duo_workflows_checkpoint, workflow: workflow)
      checkpoint2 = create(:duo_workflows_checkpoint, workflow: workflow)
      workflow.checkpoints << checkpoint1
      workflow.checkpoints << checkpoint2

      get api(path, user)
      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.pluck('id')).to eq([checkpoint2.id.first, checkpoint1.id.first])
      expect(json_response.pluck('thread_ts')).to eq([checkpoint2.thread_ts, checkpoint1.thread_ts])
      expect(json_response.pluck('parent_ts')).to eq([checkpoint2.parent_ts, checkpoint1.parent_ts])
      expect(json_response[0]).to have_key('checkpoint')
      expect(json_response[0]).not_to have_key('compressed_checkpoint')
      expect(json_response[0]).to have_key('metadata')
    end

    context 'with accept_compressed parameter' do
      it 'returns compressed checkpoints when accept_compressed is true' do
        checkpoint = create(:duo_workflows_checkpoint, workflow: workflow)
        workflow.checkpoints << checkpoint

        get api(path, user), params: { accept_compressed: true }
        expect(response).to have_gitlab_http_status(:ok)

        compressed_data = json_response[0]['compressed_checkpoint']
        expect(compressed_data).to eq('eJyrVspOrVSyUipLzClNVaoFAChMBSE=')
        decompressed = ::Gitlab::Json.parse(Zlib::Inflate.inflate(Base64.strict_decode64(compressed_data)))
        expect(decompressed).to eq(checkpoint.checkpoint)
        expect(json_response[0]).not_to have_key('checkpoint')
      end

      it 'returns uncompressed checkpoints when accept_compressed is false' do
        checkpoint = create(:duo_workflows_checkpoint, workflow: workflow)
        workflow.checkpoints << checkpoint

        get api(path, user), params: { accept_compressed: false }
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response[0]['checkpoint']).to eq(checkpoint.checkpoint)
        expect(json_response[0]).not_to have_key('compressed_checkpoint')
      end

      it 'returns uncompressed checkpoints by default' do
        checkpoint = create(:duo_workflows_checkpoint, workflow: workflow)
        workflow.checkpoints << checkpoint

        get api(path, user)
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response[0]['checkpoint']).to eq(checkpoint.checkpoint)
      end
    end
  end

  describe 'GET /ai/duo_workflows/workflows/:id/checkpoints/:checkpoint_id' do
    it 'returns the checkpoint' do
      checkpoint = create(:duo_workflows_checkpoint, workflow: workflow)
      checkpoint_write = create(:duo_workflows_checkpoint_write, thread_ts: checkpoint.thread_ts,
        workflow: checkpoint.workflow)
      path = "/ai/duo_workflows/workflows/#{workflow.id}/checkpoints/#{checkpoint.id.first}"

      get api(path, user)
      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['id']).to eq(checkpoint.id.first)
      expect(json_response['thread_ts']).to eq(checkpoint.thread_ts)
      expect(json_response['parent_ts']).to eq(checkpoint.parent_ts)
      expect(json_response).to have_key('checkpoint')
      expect(json_response).to have_key('metadata')
      expect(json_response['checkpoint_writes'][0]['id']).to eq(checkpoint_write.id)
      expect(json_response).not_to have_key('compressed_checkpoint')
    end

    context 'when a checkpoint from a workflow belongs to a different user' do
      it 'returns 404' do
        workflow = create(:duo_workflows_workflow, project: project)
        checkpoint = create(:duo_workflows_checkpoint, workflow: workflow)
        create(:duo_workflows_checkpoint_write, thread_ts: checkpoint.thread_ts,
          workflow: checkpoint.workflow)
        path = "/ai/duo_workflows/workflows/#{workflow.id}/checkpoints/#{checkpoint.id.first}"
        get api(path, user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with accept_compressed parameter' do
      it 'returns compressed checkpoint when accept_compressed is true' do
        checkpoint = create(:duo_workflows_checkpoint, workflow: workflow)
        create(:duo_workflows_checkpoint_write, thread_ts: checkpoint.thread_ts, workflow: checkpoint.workflow)
        path = "/ai/duo_workflows/workflows/#{workflow.id}/checkpoints/#{checkpoint.id.first}"

        get api(path, user), params: { accept_compressed: true }
        expect(response).to have_gitlab_http_status(:ok)

        compressed_data = json_response['compressed_checkpoint']
        decompressed = ::Gitlab::Json.parse(Zlib::Inflate.inflate(Base64.strict_decode64(compressed_data)))
        expect(decompressed).to eq(checkpoint.checkpoint)
        expect(json_response['checkpoint_writes']).to be_present
        expect(json_response).not_to have_key('checkpoint')
      end

      it 'returns uncompressed checkpoint when accept_compressed is false' do
        checkpoint = create(:duo_workflows_checkpoint, workflow: workflow)
        path = "/ai/duo_workflows/workflows/#{workflow.id}/checkpoints/#{checkpoint.id.first}"

        get api(path, user), params: { accept_compressed: false }
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['checkpoint']).to eq(checkpoint.checkpoint)
        expect(json_response).not_to have_key('compressed_checkpoint')
      end
    end
  end

  describe 'POST /ai/duo_workflows/workflows/:id/checkpoint_writes_batch' do
    let(:params) do
      {
        thread_ts: 'checkpoint_id',
        checkpoint_writes: [task: 'id', idx: 0, channel: 'channel', write_type: 'type', data: 'data']
      }
    end

    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/checkpoint_writes_batch" }

    it 'allows updating a workflow' do
      post api(path, user), params: params

      expect(response).to have_gitlab_http_status(:success)
    end

    context 'with namespace-level chat workflow' do
      let(:workflow_definition) { 'chat' }
      let(:container_params) { { namespace_id: group.id } }

      it 'allows updating a workflow' do
        expect(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :agentic_chat).and_return(true)

        post api(path, user), params: params

        expect(response).to have_gitlab_http_status(:success)
      end
    end

    context 'with a workflow belonging to a different user' do
      let(:workflow) { create(:duo_workflows_workflow) }

      it 'returns 404' do
        post api(path, user), params: params

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with invalid input' do
      let(:params) do
        {
          thread_ts: 'checkpoint_id',
          checkpoint_writes: [task: '', idx: 0, channel: 'channel', write_type: 'type', data: 'data']
        }
      end

      it 'returns bad request' do
        post api(path, user), params: params

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(response.body).to eq({ message: "400 Bad request - Validation failed: Task can't be blank" }.to_json)
      end
    end
  end

  describe 'POST /ai/duo_workflows/workflows/:id/events' do
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/events" }
    let(:correlation_id) { nil }
    let(:params) do
      {
        event_type: 'message',
        message: 'Hello, World!',
        correlation_id: correlation_id
      }
    end

    context 'when success' do
      it 'creates a new event' do
        expect do
          post api(path, user), params: params
          expect(response).to have_gitlab_http_status(:created)
        end.to change { workflow.events.count }.by(1)

        created_event = Ai::DuoWorkflows::Event.last
        expect(json_response['id']).to eq(created_event.id)
        expect(json_response['event_type']).to eq('message')
        expect(json_response['message']).to eq('Hello, World!')
        expect(json_response['event_status']).to eq('queued')
        expect(created_event.project_id).to eq(project.id)
      end

      context 'when authenticated with a token that has the ai_workflows scope' do
        it 'is successful' do
          expect do
            post api(path, oauth_access_token: ai_workflows_oauth_token), params: params
            expect(response).to have_gitlab_http_status(:created)
          end.to change { workflow.events.count }.by(1)
        end

        it "fails when creating an event for another user's remote execution workflow" do
          other_user = create(:user, maintainer_of: project)
          other_workflow = create(:duo_workflows_workflow, user: other_user, project: project, environment: :web,
            workflow_definition: :convert_to_gitlab_ci)
          event_path = "/ai/duo_workflows/workflows/#{other_workflow.id}/events"

          post api(event_path, oauth_access_token: ai_workflows_oauth_token), params: params

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when correlation_id is provided' do
        let(:correlation_id) { '123e4567-e89b-12d3-a456-426614174000' }

        it 'creates an event with the provided correlation_id' do
          expect do
            post api(path, oauth_access_token: ai_workflows_oauth_token), params: params
            expect(response).to have_gitlab_http_status(:created)
          end.to change { workflow.events.count }.by(1)
          expect(json_response['correlation_id']).to eq(correlation_id)
        end
      end

      context 'with namespace-level chat workflow' do
        let(:workflow_definition) { 'chat' }
        let(:container_params) { { namespace_id: group.id } }

        it 'allows updating a workflow' do
          expect(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :agentic_chat).and_return(true)

          post api(path, user), params: params

          created_event = Ai::DuoWorkflows::Event.last
          expect(created_event.namespace_id).to eq(group.id)
        end
      end

      context 'when an invalid correlation_id is provided' do
        let(:correlation_id) { 'invalid_id' }

        it 'rejects an invalid correlation_id' do
          post api(path, user), params: params
          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to include('correlation_id is invalid')
        end
      end
    end

    context 'when required parameters are missing' do
      it 'returns bad request when event_type is missing' do
        post api(path, user), params: params.except(:event_type)
        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to include("event_type is missing")
      end

      it 'returns bad request when message is missing' do
        post api(path, user), params: params.except(:message)
        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to include("message is missing")
      end
    end

    context 'when invalid event_type is provided' do
      it 'returns bad request' do
        post api(path, user), params: params.merge(event_type: 'invalid_event_type')
        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to include("event_type does not have a valid value")
      end
    end

    context 'with a workflow belonging to a different user' do
      let(:workflow) { create(:duo_workflows_workflow) }

      it 'returns 404' do
        post api(path, user), params: params
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET /ai/duo_workflows/workflows/:id/events' do
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/events" }

    it 'returns queued events for the workflow' do
      event1 = create(:duo_workflows_event, workflow: workflow, event_status: :queued)
      event2 = create(:duo_workflows_event, workflow: workflow, event_status: :queued)

      get api(path, user)
      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.size).to eq(2)
      # rubocop:disable Rails/Pluck -- json_response is an array of hashes, we can't use pluck
      expect(json_response.map { |e| e['id'] }).to contain_exactly(event1.id, event2.id)
      expect(json_response.map { |e| e['event_status'] }).to all(eq('queued'))
      # rubocop:enable Rails/Pluck
    end

    it 'returns empty array if no queued events' do
      create(:duo_workflows_event, workflow: workflow, event_status: :delivered)

      get api(path, user)
      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to be_empty
    end

    context 'with a workflow belonging to a different user' do
      let(:workflow) { create(:duo_workflows_workflow) }

      it 'returns 404' do
        get api(path, user)
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'PUT /ai/duo_workflows/workflows/:id/events/:event_id' do
    let(:event) { create(:duo_workflows_event, workflow: workflow, event_status: :queued) }
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/events/#{event.id}" }
    let(:params) { { event_status: 'delivered' } }

    context 'when success' do
      it 'updates the event status' do
        put api(path, user), params: params
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['id']).to eq(event.id)
        expect(json_response['event_status']).to eq('delivered')
        expect(event.reload.event_status).to eq('delivered')
      end

      context 'when authenticated with a token that has the ai_workflows scope' do
        it 'is successful' do
          put api(path, oauth_access_token: ai_workflows_oauth_token), params: params
          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    context 'when invalid event_status is provided' do
      it 'returns bad request' do
        put api(path, user), params: { event_status: 'InvalidStatus' }
        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to include("event_status does not have a valid value")
      end
    end

    context 'when the event does not exist' do
      let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}/events/0" }

      it 'returns 404' do
        put api(path, user), params: params
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with a workflow belonging to a different user' do
      let(:workflow) { create(:duo_workflows_workflow) }

      it 'returns 404' do
        put api(path, user), params: params
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with an event belonging to a different workflow' do
      let(:other_workflow) { create(:duo_workflows_workflow, user: user, project: project) }
      let(:event) { create(:duo_workflows_event, workflow: other_workflow) }

      it 'returns 404' do
        put api(path, user), params: params
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET /ai/duo_workflows/workflows/:id' do
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}" }

    before do
      allow(Gitlab::AiGateway)
        .to receive(:public_headers)
        .with(user: user, ai_feature_name: :duo_workflow, unit_primitive_name: :duo_workflow_execute_workflow)
        .and_return({ 'x-gitlab-enabled-feature-flags' => 'test-feature' })
    end

    it 'returns the Ai::DuoWorkflows::Workflow' do
      get api(path, user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['id']).to eq(workflow.id)
      expect(json_response['project_id']).to eq(project.id)
      expect(json_response['agent_privileges']).to eq(workflow.agent_privileges)
      expect(json_response['agent_privileges_names']).to eq(["read_write_files"])
      expect(json_response['pre_approved_agent_privileges']).to eq(workflow.pre_approved_agent_privileges)
      expect(json_response['pre_approved_agent_privileges_names']).to eq(["read_write_files"])
      expect(json_response['allow_agent_to_request_user']).to be(true)
      expect(json_response['mcp_enabled']).to be(true)
      expect(json_response['gitlab_url']).to eq(Gitlab.config.gitlab.url)
      expect(json_response['status']).to eq("created")
      expect(json_response['ai_catalog_item_version_id']).to eq(ai_catalog_item_version.id)
      expect(response.headers['X-Gitlab-Enabled-Feature-Flags']).to include('test-feature')
    end

    context 'when authenticated with a token that has the ai_workflows scope' do
      it 'returns the Ai::DuoWorkflows::Workflow' do
        get api(path, oauth_access_token: ai_workflows_oauth_token)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['id']).to eq(workflow.id)
      end
    end

    context 'when authenticated with a composite identity token' do
      let(:service_account) do
        create(:user, :service_account, developer_of: workflow.project, composite_identity_enforced: true)
      end

      let(:composite_oauth_token) do
        create(:oauth_access_token, user: service_account, scopes: ['ai_workflows', "user:#{user.id}"])
      end

      before do
        allow(Gitlab::AiGateway).to receive(:public_headers)
          .with(user: service_account, ai_feature_name: :duo_workflow,
            unit_primitive_name: :duo_workflow_execute_workflow)
          .and_return({})
      end

      it 'returns the Ai::DuoWorkflows::Workflow' do
        get api(path, oauth_access_token: composite_oauth_token)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['id']).to eq(workflow.id)
      end
    end

    context 'when duo_features_enabled settings is turned off' do
      before do
        workflow.project.project_setting.update!(duo_features_enabled: false)
        workflow.project.reload
      end

      it 'returns forbidden' do
        get api(path, user)
        expect(response).to have_gitlab_http_status(:forbidden)
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

  describe 'PATCH /ai/duo_workflows/workflows/:id' do
    let(:path) { "/ai/duo_workflows/workflows/#{workflow.id}" }

    context 'when update workflow status service returns error' do
      before do
        allow_next_instance_of(::Ai::DuoWorkflows::UpdateWorkflowStatusService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(reason: :bad_request,
            message: 'Cannot update workflow status'))
        end
      end

      it 'returns http error status and error message' do
        patch api(path, user), params: { status_event: "finish" }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq('Cannot update workflow status')
      end
    end

    context 'when update workflow status service returns success' do
      before do
        allow_next_instance_of(::Ai::DuoWorkflows::UpdateWorkflowStatusService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: { workflow: workflow },
            message: 'Workflow status updated'))
        end
      end

      it 'returns http status ok' do
        patch api(path, user), params: { status_event: "finish" }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['workflow']['id']).to eq(workflow.id)
      end
    end

    context 'when duo_features_enabled settings is turned off' do
      before do
        workflow.project.project_setting.update!(duo_features_enabled: false)
        workflow.project.reload
      end

      it 'returns forbidden' do
        patch api(path, user), params: { status_event: "finish" }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'POST /ai/duo_workflows/revoke_token' do
    let(:path) { "/ai/duo_workflows/revoke_token" }

    context 'when service returns an error with :invalid_token_ownership reason' do
      it 'returns forbidden status' do
        allow_next_instance_of(::Ai::DuoWorkflows::RevokeTokenService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(
            reason: :invalid_token_ownership,
            message: 'Invalid token ownership'
          ))
        end

        post api(path, oauth_access_token: ai_workflows_oauth_token), params: { token: ai_workflows_oauth_token.token }
        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response['message']).to eq('Invalid token ownership')
      end
    end

    context 'when service returns an error with :insufficient_token_scope reason' do
      it 'returns forbidden status' do
        allow_next_instance_of(::Ai::DuoWorkflows::RevokeTokenService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(
            reason: :insufficient_token_scope,
            message: 'Insufficient token scope'
          ))
        end

        post api(path, oauth_access_token: ai_workflows_oauth_token), params: { token: ai_workflows_oauth_token.token }
        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response['message']).to eq('Insufficient token scope')
      end
    end

    context 'when service returns an error with :failed_to_revoke reason' do
      it 'returns unprocessable entity status' do
        allow_next_instance_of(::Ai::DuoWorkflows::RevokeTokenService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(
            reason: :failed_to_revoke,
            message: 'Could not revoke token'
          ))
        end

        post api(path, oauth_access_token: ai_workflows_oauth_token), params: { token: ai_workflows_oauth_token.token }
        expect(response).to have_gitlab_http_status(:unprocessable_entity)
        expect(json_response['message']).to eq('Could not revoke token')
      end
    end

    context 'when service returns success' do
      it 'returns ok status with the response payload' do
        allow_next_instance_of(::Ai::DuoWorkflows::RevokeTokenService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: {}, message: 'Token revoked'))
        end

        post api(path, oauth_access_token: ai_workflows_oauth_token), params: { token: ai_workflows_oauth_token.token }
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq({})
      end
    end
  end
end
