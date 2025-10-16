# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ai::DuoWorkflows::Workflows, :with_current_organization, feature_category: :agent_foundations do
  include HttpBasicAuthHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:user) { create(:user, maintainer_of: project) }
  let_it_be(:workflow) { create(:duo_workflows_workflow, user: user, project: project) }
  let_it_be(:duo_workflow_service_url) { 'duo-workflow-service.example.com:50052' }
  let_it_be(:ai_workflows_oauth_token) { create(:oauth_access_token, user: user, scopes: [:ai_workflows]) }
  let(:agent_privileges) { [::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES] }
  let(:pre_approved_agent_privileges) { [::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES] }
  let(:workflow_definition) { 'software_development' }
  let(:allow_agent_to_request_user) { false }
  let_it_be(:service_account) { create(:user, :service_account, composite_identity_enforced: true) }

  before_all do
    group.add_developer(user)
  end

  before do
    stub_feature_flags(duo_agent_platform_enable_direct_http: false)
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)

    allow_any_instance_of(User).to receive(:allowed_to_use?).and_return(true) # rubocop:disable RSpec/AnyInstanceOf -- not the next instance

    allow_next_instance_of(::Ai::DuoWorkflows::CreateCompositeOauthAccessTokenService) do |service|
      allow(service).to receive(:execute).and_return(
        ServiceResponse.success(
          payload: {
            oauth_access_token: instance_double('Doorkeeper::AccessToken', plaintext_token: 'token-12345')
          }
        )
      )
    end

    ::Ai::Setting.instance.update!(
      duo_workflow_service_account_user_id: service_account.id
    )
    project.update!(allow_composite_identities_to_run_pipelines: true)
    project.reload
  end

  describe 'POST /ai/duo_workflows/workflows' do
    let(:path) { "/ai/duo_workflows/workflows" }
    let(:container) { { project_id: project.id } }
    let(:params) do
      {
        agent_privileges: agent_privileges,
        pre_approved_agent_privileges: pre_approved_agent_privileges,
        workflow_definition: workflow_definition,
        allow_agent_to_request_user: allow_agent_to_request_user,
        image: "example.com/example-image:latest",
        environment: "web"
      }.merge(container)
    end

    context 'when workflow is chat' do
      let(:workflow_definition) { 'chat' }

      before do
        allow(Gitlab::AiGateway).to receive(:public_headers)
          .with(user: user, ai_feature_name: :duo_workflow, unit_primitive_name: :duo_workflow_execute_workflow)
          .and_return({ 'x-gitlab-enabled-feature-flags' => 'test-feature' })
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :access_duo_agentic_chat, project).and_return(true)
      end

      it 'creates the Ai::DuoWorkflows::Workflow' do
        expect do
          post api(path, user), params: params
          expect(response).to have_gitlab_http_status(:created)
        end.to change { Ai::DuoWorkflows::Workflow.count }.by(1)

        created_workflow = Ai::DuoWorkflows::Workflow.last

        expect(created_workflow.workflow_definition).to eq(workflow_definition)
      end

      context 'with namespace-level workflow' do
        let(:container) { { namespace_id: group.id } }

        before do
          allow(Ability).to receive(:allowed?).with(user, :access_duo_agentic_chat, group).and_return(true)
        end

        it 'creates a workflow' do
          post api(path, user), params: params

          created_workflow = Ai::DuoWorkflows::Workflow.last
          expect(json_response['id']).to eq(created_workflow.id)
          expect(json_response['namespace_id']).to eq(created_workflow.namespace.id)
          expect(json_response['namespace_id']).to eq(group.id)
          expect(json_response['project_id']).to be_nil
        end
      end

      context 'when both project_id and namespace_id are specified' do
        let(:container) { { project_id: project.id, namespace_id: group.id } }

        it 'returns error' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(response.body).to include('project_id, namespace_id are mutually exclusive')
        end
      end
    end

    context 'when success' do
      before do
        allow(Gitlab::AiGateway).to receive(:public_headers)
          .with(user: user, ai_feature_name: :duo_workflow, unit_primitive_name: :duo_workflow_execute_workflow)
          .and_return({ 'x-gitlab-enabled-feature-flags' => 'test-feature' })
      end

      it 'creates the Ai::DuoWorkflows::Workflow' do
        expect do
          post api(path, user), params: params
          expect(response).to have_gitlab_http_status(:created)
        end.to change { Ai::DuoWorkflows::Workflow.count }.by(1)

        expect(json_response['id']).to eq(Ai::DuoWorkflows::Workflow.last.id)
        expect(json_response['environment']).to eq("web")
        expect(response.headers['X-Gitlab-Enabled-Feature-Flags']).to include('test-feature')

        created_workflow = Ai::DuoWorkflows::Workflow.last

        expect(created_workflow.agent_privileges).to eq(agent_privileges)
        expect(created_workflow.pre_approved_agent_privileges).to eq(pre_approved_agent_privileges)
        expect(created_workflow.workflow_definition).to eq(workflow_definition)
        expect(created_workflow.allow_agent_to_request_user).to eq(allow_agent_to_request_user)
        expect(created_workflow.image).to eq("example.com/example-image:latest")
        expect(created_workflow.environment).to eq("web")
      end

      context 'with namespace-level workflow' do
        let(:container) { { namespace_id: group.id } }

        # NOTE: Non-chat types do not support namespace-level workflow yet.
        # See https://gitlab.com/gitlab-org/gitlab/-/issues/554952.
        it 'does not support a namespace-level workflow yet' do
          post api(path, user), params: params

          expect(json_response['message']).to eq('403 Forbidden - forbidden to access duo workflow')
        end
      end

      context 'when agent_privileges is not provided' do
        let(:params) { { project_id: project.id } }

        it 'creates a workflow with the default agent_privileges' do
          post api(path, user), params: params
          expect(response).to have_gitlab_http_status(:created)

          created_workflow = Ai::DuoWorkflows::Workflow.last
          expect(created_workflow.agent_privileges).to match_array(
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::DEFAULT_PRIVILEGES
          )
        end
      end

      context 'when pre_approved_agent_privileges is not provided' do
        let(:params) do
          {
            project_id: project.id,
            agent_privileges: ::Ai::DuoWorkflows::Workflow::AgentPrivileges::DEFAULT_PRIVILEGES
          }
        end

        it 'creates a workflow with the default pre_approved_agent_privileges' do
          post api(path, user), params: params
          expect(response).to have_gitlab_http_status(:created)

          created_workflow = Ai::DuoWorkflows::Workflow.last
          expect(created_workflow.pre_approved_agent_privileges).to match_array(
            ::Ai::DuoWorkflows::Workflow::AgentPrivileges::DEFAULT_PRIVILEGES
          )
        end
      end

      context 'when pre_approved_agent_privileges has invalid privilege' do
        let(:params) do
          {
            project_id: project.id,
            agent_privileges: [::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES],
            pre_approved_agent_privileges: [999]
          }
        end

        it 'returns bad request' do
          post api(path, user), params: params
          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when pre_approved_agent_privileges contains privilege not in agent_privileges' do
        let(:params) do
          {
            project_id: project.id,
            agent_privileges: [::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES],
            pre_approved_agent_privileges: [::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_GITLAB]
          }
        end

        it 'returns bad request' do
          post api(path, user), params: params
          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when allow_agent_to_request_user is not provided' do
        it 'creates a workflow with the default of true' do
          post api(path, user), params: params.except(:allow_agent_to_request_user)
          expect(response).to have_gitlab_http_status(:created)

          created_workflow = Ai::DuoWorkflows::Workflow.last
          expect(created_workflow.allow_agent_to_request_user).to eq(true)
        end
      end

      context 'when workflow definition is not provided' do
        let(:params) { { project_id: project.id } }

        it 'creates a workflow with the default workflow_definition' do
          post api(path, user), params: params
          expect(response).to have_gitlab_http_status(:created)

          created_workflow = Ai::DuoWorkflows::Workflow.last
          expect(created_workflow.workflow_definition).to eq('software_development')
        end
      end

      context 'when authenticated with a token that has the ai_workflows scope' do
        it 'is forbidden' do
          post api(path, oauth_access_token: ai_workflows_oauth_token), params: params

          expect(response).to have_gitlab_http_status(:forbidden)
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

      context 'when environment is chat_partial' do
        let(:params) { { project_id: project.id, environment: 'chat_partial' } }

        it 'creates a workflow with chat_partial environment' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
          created_workflow = Ai::DuoWorkflows::Workflow.last
          expect(created_workflow.environment).to eq('chat_partial')
        end
      end
    end

    context 'when failure' do
      shared_examples 'workflow access is forbidden' do
        it 'workflow access is forbidden' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'with a project where the user is not a developer' do
        let(:user) { create(:user, guest_of: project) }

        it_behaves_like 'workflow access is forbidden'
      end

      context 'when the duo_workflows feature flag is disabled for the user' do
        before do
          stub_feature_flags(duo_workflow: false)
        end

        it_behaves_like 'workflow access is forbidden'
      end

      context 'when duo_features_enabled settings is turned off' do
        before do
          project.project_setting.update!(duo_features_enabled: false)
          project.reload
        end

        it_behaves_like 'workflow access is forbidden'
      end

      context 'with namespace-level workflow' do
        let(:container) { { namespace_id: group.id } }

        before do
          group.namespace_settings.update!(duo_features_enabled: false)
          group.reload
        end

        it_behaves_like 'workflow access is forbidden'
      end
    end

    context 'when start_workflow is true' do
      before_all do
        project.project_setting.update!(duo_remote_flows_enabled: true)
      end

      shared_examples 'starts duo workflow execution in CI' do
        it 'creates a pipeline to run the workflow' do
          expect_next_instance_of(Ci::CreatePipelineService) do |pipeline_service|
            expect(pipeline_service).to receive(:execute).and_call_original
          end

          post api(path, user), params: params
          expect(json_response['id']).to eq(Ai::DuoWorkflows::Workflow.last.id)
          expect(json_response['workload']['id']).to eq(Ci::Workloads::Workload.last.id)
          expect(::Ci::Pipeline.last.project_id).to eq(project.id)
        end
      end

      shared_examples 'workflow execution blocked in CI' do
        it 'does not start a CI pipeline' do
          post api(path, user), params: params

          expect(json_response.dig('workload', 'id')).to eq(nil)
          expect(json_response.dig('workload', 'message')).to eq('Can not execute workflow in CI')
        end
      end

      let(:params) do
        {
          project_id: project.id,
          start_workflow: true,
          goal: 'Print hello world'
        }
      end

      before do
        allow_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
          allow(client).to receive(:generate_token).and_return(
            ServiceResponse.success(payload: { token: "an-encrypted-token" })
          )
        end
        allow_next_instance_of(::Ai::DuoWorkflows::CreateOauthAccessTokenService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.success(
              payload: {
                oauth_access_token: instance_double('Doorkeeper::AccessToken', plaintext_token: 'oauth_token')
              }
            )
          )
        end
      end

      it_behaves_like 'starts duo workflow execution in CI'

      context 'when Feature flag is disabled' do
        before do
          stub_feature_flags(duo_workflow_in_ci: false)
        end

        include_examples 'workflow execution blocked in CI'
      end

      context 'when duo_remote_flows_enabled settings is turned off' do
        before do
          project.project_setting.update!(duo_remote_flows_enabled: false)
          project.reload
        end

        include_examples 'workflow execution blocked in CI'
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
          expect(json_response.dig('workload', 'id')).to eq(nil)
          expect(json_response.dig('workload', 'message')).to eq('Error in creating workload: full error messages')
        end
      end

      context 'when duo_workflow_use_composite_identity feature flag is disabled' do
        it 'uses regular OAuth token' do
          stub_feature_flags(duo_workflow_use_composite_identity: false)
          expect(::Ai::DuoWorkflows::CreateCompositeOauthAccessTokenService).not_to receive(:new)
          expect(::Ai::DuoWorkflows::CreateOauthAccessTokenService).to receive(:new)

          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
        end

        it_behaves_like 'starts duo workflow execution in CI'
      end

      context 'when valid additional_context is provided' do
        let(:params) do
          {
            project_id: project.id,
            start_workflow: true,
            goal: 'valid additional context',
            additional_context: [
              {
                Category: "agent_user_environment",
                Content: "some content",
                Metadata: "{}"
              }
            ]
          }
        end

        it 'passes additional_context to StartWorkflowService' do
          expect(::Ai::DuoWorkflows::StartWorkflowService).to receive(:new).with(
            workflow: anything,
            params: hash_including(:additional_context)
          ).and_call_original

          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
        end
      end

      context 'when invalid additional_context is provided' do
        let(:params) do
          {
            project_id: project.id,
            start_workflow: true,
            goal: 'valid additional context',
            additional_context: "agent_user_environment"
          }
        end

        it 'passes additional_context to StartWorkflowService' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response).to eq({
            "error" => "additional_context is invalid, additional_context does not have a valid value"
          })
        end
      end

      context 'when source_branch is provided' do
        let(:params) do
          {
            project_id: project.id,
            start_workflow: true,
            goal: 'Print hello world',
            source_branch: 'feature-branch'
          }
        end

        it 'passes source_branch to StartWorkflowService' do
          expect(::Ai::DuoWorkflows::StartWorkflowService).to receive(:new).with(
            workflow: anything,
            params: hash_including(source_branch: 'feature-branch')
          ).and_call_original

          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
        end
      end

      context 'when environment argument has invalid value' do
        let(:params) { super().merge(environment: 'invalid') }

        it 'returns bad request' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response).to eq({ "error" => "environment does not have a valid value" })
        end
      end

      context 'when ai_catalog_item_version_id is provided' do
        let_it_be(:ai_catalog_item) { create(:ai_catalog_item) }
        let_it_be(:ai_catalog_item_version) { create(:ai_catalog_item_version, item: ai_catalog_item) }
        let(:params) { super().merge(ai_catalog_item_version_id: ai_catalog_item_version.id) }

        before do
          allow_next_instance_of(Ai::Catalog::ItemConsumersFinder) do |finder|
            allow(finder).to receive(:execute).and_return(class_double(::Ai::Catalog::ItemConsumer, exists?: true))
          end
        end

        it 'creates a workflow with the AI catalog item version' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['ai_catalog_item_version_id']).to eq(ai_catalog_item_version.id)
          created_workflow = Ai::DuoWorkflows::Workflow.last
          expect(created_workflow.ai_catalog_item_version).to eq(ai_catalog_item_version)
        end

        context 'when user does not have access to the AI catalog item' do
          before do
            allow_next_instance_of(Ai::Catalog::ItemConsumersFinder) do |finder|
              allow(finder).to receive(:execute).and_return(class_double(::Ai::Catalog::ItemConsumer, exists?: false))
            end
          end

          it 'returns not found error' do
            post api(path, user), params: params

            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response['message']).to include('ItemVersion not found')
          end
        end

        context 'when ai_catalog_item_version_id does not exist' do
          let(:params) { super().merge(ai_catalog_item_version_id: non_existing_record_id) }

          it 'returns not found error' do
            post api(path, user), params: params

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end

      context 'when OAuth token creation fails' do
        before do
          allow_next_instance_of(::Ai::DuoWorkflows::TokenGenerationService) do |service|
            allow(service).to receive(:generate_oauth_token_with_composite_identity_support)
              .and_return(ServiceResponse.error(message: 'OAuth token creation failed', http_status: :forbidden)) # rubocop:disable Gitlab/ServiceResponse -- Preserve the actual behavior of the service response.
          end
        end

        it 'returns api error' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when workflow token creation fails' do
        before do
          allow_next_instance_of(::Ai::DuoWorkflows::TokenGenerationService) do |service|
            allow(service).to receive(:generate_workflow_token)
              .and_return(ServiceResponse.error(message: 'workflow token creation failed'))
          end
        end

        it 'returns api error' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when shallow_clone is not provided' do
        it 'starts the workflow with a shallow clone' do
          expect(::Ai::DuoWorkflows::StartWorkflowService).to receive(:new).with(
            workflow: anything,
            params: hash_including(shallow_clone: true)
          ).and_call_original

          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
        end
      end

      context 'when shallow_clone is true' do
        let(:params) do
          super().merge(shallow_clone: true)
        end

        it 'starts the workflow with a shallow clone' do
          expect(::Ai::DuoWorkflows::StartWorkflowService).to receive(:new).with(
            workflow: anything,
            params: hash_including(shallow_clone: true)
          ).and_call_original

          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
        end
      end

      context 'when shallow_clone is false' do
        let(:params) do
          super().merge(shallow_clone: false)
        end

        it 'starts the workflow with a regular clone' do
          expect(::Ai::DuoWorkflows::StartWorkflowService).to receive(:new).with(
            workflow: anything,
            params: hash_including(shallow_clone: false)
          ).and_call_original

          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
        end
      end
    end
  end

  describe 'POST /ai/duo_workflows/direct_access' do
    let(:path) { '/ai/duo_workflows/direct_access' }

    let(:post_without_params) { post api(path, user) }
    let(:post_with_definition) { post api(path, user), params: { workflow_definition: workflow_definition } }

    before do
      allow(Gitlab.config.duo_workflow).to receive(:service_url).and_return duo_workflow_service_url
      stub_config(duo_workflow: {
        executor_binary_url: 'https://example.com/executor',
        executor_binary_urls: {
          'linux/arm' => 'https://example.com/linux-arm-executor.tar.gz',
          'darwin/arm64' => 'https://example.com/darwin-arm64-executor.tar.gz'
        },
        service_url: duo_workflow_service_url,
        executor_version: 'v1.2.3',
        secure: true
      })
    end

    context 'when the duo_workflows is disabled for the user' do
      before do
        stub_feature_flags(duo_workflow: false)
      end

      context 'when workflow_definition is software_developer' do
        let(:workflow_definition) { 'software_developer' }

        it 'returns not found' do
          post_with_definition

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when workflow_definition is chat' do
        let(:workflow_definition) { 'chat' }

        it 'process request further' do
          post_with_definition

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when workflow_definition is omitted' do
        it 'process request further' do
          post_without_params

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end

    context 'when agentic_chat feature flag is disabled for the user' do
      before do
        stub_feature_flags(duo_agentic_chat: false)
      end

      context 'when workflow_definition is chat' do
        let(:workflow_definition) { 'chat' }

        it 'returns not found' do
          post_with_definition

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when workflow_definition is software_developer' do
        let(:workflow_definition) { 'software_developer' }

        it 'process request further' do
          post_with_definition

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end

    context 'when the duo_workflows and agentic_chat feature flag is disabled for the user' do
      before do
        stub_feature_flags(duo_workflow: false)
        stub_feature_flags(duo_agentic_chat: false)
      end

      it 'returns not found' do
        post_without_params

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when rate limited' do
      it 'returns api error' do
        allow(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?).and_return(true)

        post_without_params

        expect(response).to have_gitlab_http_status(:too_many_requests)
        expect(response.headers)
          .to include('Retry-After' => Gitlab::ApplicationRateLimiter.interval(:duo_workflow_direct_access))
      end
    end

    context 'when CreateOauthAccessTokenService returns error' do
      it 'returns api error' do
        expect_next_instance_of(::Ai::DuoWorkflows::CreateOauthAccessTokenService) do |service|
          expect(service).to receive(:execute).and_return(
            ServiceResponse.error(message: 'Duo workflow is not enabled for user', http_status: :forbidden) # rubocop:disable Gitlab/ServiceResponse -- Preserve the actual behavior of the service response.
          )
        end

        post_without_params

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when DuoWorkflowService returns error' do
      it 'returns api error' do
        expect_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
          expect(client).to receive(:generate_token).and_return(
            ServiceResponse.error(message: "could not generate token")
          )
        end

        post_without_params

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when success' do
      let(:gitlab_rails_token_expires_at) { 2.hours.from_now.to_i }
      let(:duo_workflow_service_token_expires_at) { 1.hour.from_now.to_i }

      before do
        allow(::CloudConnector).to receive(:ai_headers).with(user).and_return({ header_key: 'header_value' })
        allow_next_instance_of(::Gitlab::Tracking::StandardContext) do |context|
          allow(context).to receive(:gitlab_team_member?).and_return(false)
          allow(context).to receive(:gitlab_team_member?).with(user.id).and_return(true)
        end
        allow_next_instance_of(::Ai::DuoWorkflows::CreateOauthAccessTokenService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.success(payload: {
              oauth_access_token: instance_double('Doorkeeper::AccessToken', plaintext_token: 'oauth_token',
                expires_at: gitlab_rails_token_expires_at)
            })
          )
        end
        allow_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
          allow(client).to receive(:generate_token).and_return(
            ServiceResponse.success(payload: { token: 'duo_workflow_token',
                                               expires_at: duo_workflow_service_token_expires_at })
          )
        end
      end

      it 'returns access payload' do
        post_without_params

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['gitlab_rails']['base_url']).to eq(Gitlab.config.gitlab.url)
        expect(json_response['gitlab_rails']['token']).to eq('oauth_token')
        expect(json_response['gitlab_rails']['token_expires_at']).to eq(gitlab_rails_token_expires_at)
        expect(json_response['duo_workflow_service']['base_url']).to eq("duo-workflow-service.example.com:50052")
        expect(json_response['duo_workflow_service']['token']).to eq('duo_workflow_token')
        expect(json_response['duo_workflow_service']['headers']['header_key']).to eq("header_value")
        expect(json_response['duo_workflow_service']['secure']).to eq(Gitlab::DuoWorkflow::Client.secure?)
        expect(json_response['duo_workflow_service']['token_expires_at']).to eq(duo_workflow_service_token_expires_at)
        expect(json_response['duo_workflow_executor']['executor_binary_url']).to eq('https://example.com/executor')
        expect(json_response['duo_workflow_executor']['version']).to eq('v1.2.3')
        expect(json_response['workflow_metadata']['extended_logging']).to eq(true)
        expect(json_response['workflow_metadata']['is_team_member']).to eq(true)
        expect(json_response['duo_workflow_executor']['executor_binary_urls']).to eq({
          'linux/arm' => 'https://example.com/linux-arm-executor.tar.gz',
          'darwin/arm64' => 'https://example.com/darwin-arm64-executor.tar.gz'
        })
      end

      context 'when duo_workflow_extended_logging is disabled' do
        before do
          stub_feature_flags(duo_workflow_extended_logging: false)
        end

        it 'returns workflow_metadata.extended_logging: false' do
          post_without_params

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['workflow_metadata']['extended_logging']).to eq(false)
        end
      end

      context 'when authenticated with a token that has the ai_workflows scope' do
        it 'is forbidden' do
          post api(path, oauth_access_token: ai_workflows_oauth_token)

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end
  end

  describe 'GET /ai/duo_workflows/ws' do
    let(:path) { '/ai/duo_workflows/ws' }
    let(:self_hosted_duo_workflow_service_url) { 'self-hosted-dap-service-url:50052' }
    let(:default_duo_workflow_service_url) { 'cloud.gitlab.com:50052' }

    include_context 'workhorse headers'

    subject(:get_response) { get api(path, user), headers: workhorse_headers }

    before do
      allow_next_instance_of(::Ai::DuoWorkflows::CreateOauthAccessTokenService) do |service|
        allow(service).to receive(:execute).and_return(
          ServiceResponse.success(payload: {
            oauth_access_token: instance_double('Doorkeeper::AccessToken', plaintext_token: 'oauth_token')
          })
        )
      end

      allow(Gitlab::DuoWorkflow::Client).to receive_messages(
        self_hosted_url: self_hosted_duo_workflow_service_url,
        default_service_url: default_duo_workflow_service_url,
        secure?: true
      )

      allow(Gitlab.config.duo_workflow).to receive(:service_url).and_return(duo_workflow_service_url)

      allow(::CloudConnector::Tokens).to receive(:get).and_return('token')
    end

    shared_examples 'ServiceURI has the right value' do |with_self_hosted_setting|
      context 'with a duo workflow service url set' do
        it 'routes to the right service uri' do
          get_response

          if with_self_hosted_setting
            expect(json_response['DuoWorkflow']['ServiceURI']).to eq(self_hosted_duo_workflow_service_url)
          else
            expect(json_response['DuoWorkflow']['ServiceURI']).to eq(duo_workflow_service_url)
          end
        end
      end

      context 'with no duo workflow service url set' do
        let(:duo_workflow_service_url) { nil }

        it 'routes to the right service uri' do
          get_response

          if with_self_hosted_setting
            expect(json_response['DuoWorkflow']['ServiceURI']).to eq(self_hosted_duo_workflow_service_url)
          else
            expect(json_response['DuoWorkflow']['ServiceURI']).to eq(default_duo_workflow_service_url)
          end
        end
      end
    end

    context 'when user is authenticated' do
      it 'returns the websocket configuration with proper headers' do
        get_response

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.media_type).to eq(Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE)

        expect(json_response['DuoWorkflow']['Headers']).to include(
          'x-gitlab-oauth-token' => 'oauth_token',
          'authorization' => 'Bearer token',
          'x-gitlab-authentication-type' => 'oidc',
          'x-gitlab-enabled-feature-flags' => anything,
          'x-gitlab-instance-id' => anything,
          'x-gitlab-version' => Gitlab.version_info.to_s,
          'x-gitlab-unidirectional-streaming' => 'enabled'
        )

        expect(json_response['DuoWorkflow']['Secure']).to eq(true)
      end

      it_behaves_like 'ServiceURI has the right value', false

      context 'when project_id parameter is provided' do
        it 'includes x-gitlab-project-id header' do
          get api(path, user), headers: workhorse_headers, params: { project_id: project.id }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Headers']).to include(
            'x-gitlab-project-id' => project.id.to_s
          )
        end

        it 'sets x-gitlab-project-id header to nil when project_id is blank' do
          get api(path, user), headers: workhorse_headers, params: { project_id: '' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Headers']['x-gitlab-project-id']).to be_nil
        end
      end

      context 'when X-Gitlab-Language-Server-Version header is provided' do
        it 'includes x-gitlab-language-server-version header' do
          get api(path, user), headers: workhorse_headers.merge('X-Gitlab-Language-Server-Version': "8.22.0"),
            params: { project_id: project.id }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Headers']).to include(
            'x-gitlab-language-server-version' => "8.22.0"
          )
        end

        it 'does not include x-gitlab-language-server-version header when header is not provided' do
          get api(path, user), headers: workhorse_headers, params: { project_id: project.id }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Headers']['x-gitlab-language-server-version']).to be_nil
        end
      end

      context 'when namespace_id parameter is provided' do
        it 'includes x-gitlab-namespace-id header' do
          get api(path, user), headers: workhorse_headers, params: { namespace_id: group.id }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Headers']).to include(
            'x-gitlab-namespace-id' => group.id.to_s
          )
        end

        it 'falls back to X-Gitlab-Namespace-Id header when namespace_id is blank' do
          get api(path, user), headers: workhorse_headers.merge('X-Gitlab-Namespace-Id' => group.id),
            params: { namespace_id: '' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Headers']).to include(
            'x-gitlab-namespace-id' => group.id.to_s,
            'x-gitlab-root-namespace-id' => group.id.to_s
          )
        end
      end

      context 'when root_namespace_id parameter is provided' do
        it 'includes x-gitlab-root-namespace-id header and sets namespace-id to root' do
          get api(path, user), headers: workhorse_headers, params: { root_namespace_id: group.id }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Headers']).to include(
            'x-gitlab-root-namespace-id' => group.id.to_s,
            'x-gitlab-namespace-id' => group.id.to_s
          )
        end

        it 'sets root_namespace_id header to nil when namespace is not found' do
          get api(path, user), headers: workhorse_headers, params: { root_namespace_id: 99999 }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Headers']['x-gitlab-root-namespace-id']).to be_nil
        end
      end

      context 'when both project_id and namespace_id parameters are provided' do
        it 'includes both x-gitlab-project-id and x-gitlab-namespace-id headers' do
          get api(path, user), headers: workhorse_headers, params: {
            project_id: project.id,
            namespace_id: group.id
          }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Headers']).to include(
            'x-gitlab-project-id' => project.id.to_s,
            'x-gitlab-namespace-id' => group.id.to_s
          )
        end
      end

      context 'when namespace is provided via X-Gitlab-Namespace-Id header' do
        it 'includes x-gitlab-namespace-id header in response' do
          get api(path, user), headers: workhorse_headers.merge('X-Gitlab-Namespace-Id' => group.id)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Headers']).to include(
            'x-gitlab-namespace-id' => group.id.to_s
          )
        end
      end

      context 'when precedence of namespace parameters is tested' do
        let_it_be(:child_group) { create(:group, parent: group) }

        it 'sets both root and namespace headers, with namespace_id taking precedence for x-gitlab-namespace-id' do
          get api(path, user), headers: workhorse_headers.merge('X-Gitlab-Namespace-Id' => child_group.id), params: {
            root_namespace_id: group.id,
            namespace_id: child_group.id
          }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Headers']).to include(
            'x-gitlab-root-namespace-id' => group.id.to_s,
            'x-gitlab-namespace-id' => child_group.id.to_s
          )
        end

        it 'uses namespace_id parameter over X-Gitlab-Namespace-Id header when root_namespace_id is not provided' do
          get api(path, user), headers: workhorse_headers.merge('X-Gitlab-Namespace-Id' => group.id), params: {
            namespace_id: child_group.id
          }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Headers']).to include(
            'x-gitlab-namespace-id' => child_group.id.to_s,
            'x-gitlab-root-namespace-id' => child_group.root_ancestor.id.to_s
          )
        end

        it 'falls back to X-Gitlab-Namespace-Id header when no namespace params are provided' do
          get api(path, user), headers: workhorse_headers.merge('X-Gitlab-Namespace-Id' => group.id)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Headers']).to include(
            'x-gitlab-namespace-id' => group.id.to_s,
            'x-gitlab-root-namespace-id' => group.id.to_s
          )
        end

        it 'uses root_namespace_id for x-gitlab-namespace-id when only root_namespace_id is provided' do
          get api(path, user), headers: workhorse_headers.merge('X-Gitlab-Namespace-Id' => child_group.id), params: {
            root_namespace_id: group.id
          }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Headers']).to include(
            'x-gitlab-root-namespace-id' => group.id.to_s,
            'x-gitlab-namespace-id' => group.id.to_s
          )
        end
      end

      context 'when duo_agent_platform_enable_direct_http is enabled' do
        subject(:get_response) do
          stub_feature_flags(duo_agent_platform_enable_direct_http: true)
          get api(path, user), headers: workhorse_headers
        end

        it 'returns the websocket configuration with proper headers' do
          get_response

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.media_type).to eq(Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE)

          expect(json_response['DuoWorkflow']['Headers']).to include(
            'x-gitlab-base-url' => Gitlab.config.gitlab.url,
            'x-gitlab-oauth-token' => 'oauth_token',
            'authorization' => 'Bearer token',
            'x-gitlab-authentication-type' => 'oidc',
            'x-gitlab-enabled-feature-flags' => anything,
            'x-gitlab-instance-id' => anything,
            'x-gitlab-version' => Gitlab.version_info.to_s,
            'x-gitlab-unidirectional-streaming' => 'enabled'
          )

          expect(json_response['DuoWorkflow']['Secure']).to eq(true)
        end

        it_behaves_like 'ServiceURI has the right value', false

        context 'when project_id parameter is provided' do
          it 'includes x-gitlab-project-id header' do
            stub_feature_flags(duo_agent_platform_enable_direct_http: true)

            get api(path, user), headers: workhorse_headers, params: { project_id: project.id }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['DuoWorkflow']['Headers']).to include(
              'x-gitlab-project-id' => project.id.to_s
            )
          end

          it 'sets x-gitlab-project-id header to nil when project_id is blank' do
            stub_feature_flags(duo_agent_platform_enable_direct_http: true)

            get api(path, user), headers: workhorse_headers, params: { project_id: '' }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['DuoWorkflow']['Headers']['x-gitlab-project-id']).to be_nil
          end
        end

        context 'when namespace_id parameter is provided' do
          it 'includes x-gitlab-namespace-id header' do
            stub_feature_flags(duo_agent_platform_enable_direct_http: true)

            get api(path, user), headers: workhorse_headers, params: { namespace_id: group.id }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['DuoWorkflow']['Headers']).to include(
              'x-gitlab-namespace-id' => group.id.to_s
            )
          end

          it 'falls back to X-Gitlab-Namespace-Id header when namespace_id is blank' do
            stub_feature_flags(duo_agent_platform_enable_direct_http: true)

            get api(path, user), headers: workhorse_headers.merge('X-Gitlab-Namespace-Id' => group.id),
              params: { namespace_id: '' }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['DuoWorkflow']['Headers']).to include(
              'x-gitlab-namespace-id' => group.id.to_s,
              'x-gitlab-root-namespace-id' => group.id.to_s
            )
          end
        end
      end

      context 'when self_hosted_agent_platform feature flag is enabled' do
        let_it_be(:self_hosted_model) do
          create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219')
        end

        let_it_be_with_refind(:duo_agent_platform_setting) do
          create(:ai_feature_setting, :duo_agent_platform, self_hosted_model: self_hosted_model)
        end

        before do
          stub_feature_flags(self_hosted_agent_platform: true)
          stub_feature_flags(instance_level_model_selection: false)
          stub_feature_flags(duo_agent_platform_model_selection: false)
          stub_feature_flags(ai_model_switching: false)
        end

        it 'includes model metadata headers in the response' do
          get_response

          expect(response).to have_gitlab_http_status(:ok)

          headers = json_response['DuoWorkflow']['Headers']
          expect(headers).to include(
            'x-gitlab-oauth-token' => 'oauth_token',
            'x-gitlab-unidirectional-streaming' => 'enabled',
            'x-gitlab-agent-platform-model-metadata' => be_a(String)
          )

          metadata = ::Gitlab::Json.parse(headers['x-gitlab-agent-platform-model-metadata'])
          expect(metadata).to include(
            'provider' => 'openai',
            'name' => 'claude_3',
            'identifier' => self_hosted_model.identifier,
            'api_key' => self_hosted_model.api_token,
            'endpoint' => self_hosted_model.endpoint
          )
        end

        it 'creates ModelMetadata with the correct feature setting' do
          expect(::Gitlab::Llm::AiGateway::AgentPlatform::ModelMetadata).to receive(:new)
            .with(feature_setting: duo_agent_platform_setting)
            .and_call_original

          get api(path, user), headers: workhorse_headers
        end

        it_behaves_like 'ServiceURI has the right value', true

        context 'when ModelMetadata returns nil' do
          subject(:get_response) do
            duo_agent_platform_setting.destroy!
            get api(path, user), headers: workhorse_headers
          end

          it 'does not include model metadata headers' do
            get_response

            expect(response).to have_gitlab_http_status(:ok)

            headers = json_response['DuoWorkflow']['Headers']
            expect(headers).to include(
              'x-gitlab-oauth-token' => 'oauth_token',
              'x-gitlab-unidirectional-streaming' => 'enabled'
            )
            expect(headers).not_to have_key('x-gitlab-agent-platform-model-metadata')
          end

          it_behaves_like 'ServiceURI has the right value', false
        end

        context 'when feature setting is disabled' do
          subject(:get_response) do
            duo_agent_platform_setting.update!(provider: :disabled)

            get api(path, user), headers: workhorse_headers
          end

          it 'does not include model metadata headers when provider is disabled' do
            get_response

            expect(response).to have_gitlab_http_status(:ok)

            headers = json_response['DuoWorkflow']['Headers']
            expect(headers).to include(
              'x-gitlab-oauth-token' => 'oauth_token',
              'x-gitlab-unidirectional-streaming' => 'enabled'
            )
            expect(headers).not_to have_key('x-gitlab-agent-platform-model-metadata')
          end

          it_behaves_like 'ServiceURI has the right value', false
        end
      end

      context 'when self_hosted_agent_platform feature flag is disabled' do
        let_it_be(:self_hosted_model) do
          create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219')
        end

        let_it_be_with_refind(:duo_agent_platform_setting) do
          create(:ai_feature_setting, :duo_agent_platform, self_hosted_model: self_hosted_model)
        end

        before do
          stub_feature_flags(self_hosted_agent_platform: false)
          stub_feature_flags(instance_level_model_selection: false)
          stub_feature_flags(duo_agent_platform_model_selection: false)
          stub_feature_flags(ai_model_switching: false)
        end

        subject(:get_response) do
          expect(::Gitlab::Llm::AiGateway::AgentPlatform::ModelMetadata).not_to receive(:new)

          get api(path, user), headers: workhorse_headers
        end

        it 'does not include model metadata headers' do
          get_response

          expect(response).to have_gitlab_http_status(:ok)

          headers = json_response['DuoWorkflow']['Headers']
          expect(headers).to include(
            'x-gitlab-oauth-token' => 'oauth_token',
            'x-gitlab-unidirectional-streaming' => 'enabled'
          )
          expect(headers).not_to have_key('x-gitlab-agent-platform-model-metadata')
        end

        it 'returns the standard websocket configuration' do
          get_response

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.media_type).to eq(Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE)

          expect(json_response['DuoWorkflow']['Headers']).to include(
            'x-gitlab-oauth-token' => 'oauth_token',
            'authorization' => 'Bearer token',
            'x-gitlab-authentication-type' => 'oidc',
            'x-gitlab-enabled-feature-flags' => anything,
            'x-gitlab-instance-id' => anything,
            'x-gitlab-version' => Gitlab.version_info.to_s,
            'x-gitlab-unidirectional-streaming' => 'enabled'
          )

          expect(json_response['DuoWorkflow']['Secure']).to eq(true)
        end

        it_behaves_like 'ServiceURI has the right value', true
      end

      context 'for model selection at instance level' do
        before do
          stub_feature_flags(instance_level_model_selection: true)
          stub_feature_flags(duo_agent_platform_model_selection: false)
          stub_feature_flags(ai_model_switching: false)
          stub_feature_flags(self_hosted_agent_platform: false)
        end

        context 'when model selection at instance level does not exist' do
          it 'includes model metadata headers with default model' do
            get_response

            expect(response).to have_gitlab_http_status(:ok)

            headers = json_response['DuoWorkflow']['Headers']
            expect(headers).to include(
              'x-gitlab-oauth-token' => 'oauth_token',
              'x-gitlab-unidirectional-streaming' => 'enabled'
            )

            metadata = ::Gitlab::Json.parse(headers['x-gitlab-agent-platform-model-metadata'])
            expect(metadata).to include(
              'provider' => 'gitlab',
              'feature_setting' => 'duo_agent_platform',
              'identifier' => nil
            )
          end

          it_behaves_like 'ServiceURI has the right value', false
        end

        context 'when model selection at instance level exists' do
          let_it_be(:instance_setting) do
            create(:instance_model_selection_feature_setting,
              feature: :duo_agent_platform,
              offered_model_ref: 'claude-3-7-sonnet-20250219')
          end

          it 'includes model metadata headers in the response' do
            get_response

            expect(response).to have_gitlab_http_status(:ok)

            headers = json_response['DuoWorkflow']['Headers']

            metadata = ::Gitlab::Json.parse(headers['x-gitlab-agent-platform-model-metadata'])
            expect(metadata).to include(
              'provider' => 'gitlab',
              'feature_setting' => 'duo_agent_platform',
              'identifier' => 'claude-3-7-sonnet-20250219'
            )
          end

          it_behaves_like 'ServiceURI has the right value', false
        end

        context 'when the feature flag is disabled' do
          before do
            stub_feature_flags(instance_level_model_selection: false)
          end

          it 'does not include model metadata headers' do
            get_response

            expect(response).to have_gitlab_http_status(:ok)

            headers = json_response['DuoWorkflow']['Headers']
            expect(headers).to include(
              'x-gitlab-oauth-token' => 'oauth_token',
              'x-gitlab-unidirectional-streaming' => 'enabled'
            )
            expect(headers).not_to have_key('x-gitlab-agent-platform-model-metadata')
          end

          it_behaves_like 'ServiceURI has the right value', false
        end
      end

      context 'for model selection at namespace level', :saas do
        include_context 'with model selections fetch definition service side-effect context'

        before do
          stub_feature_flags(instance_level_model_selection: false)
          stub_feature_flags(duo_agent_platform_model_selection: true)
          stub_feature_flags(ai_model_switching: true)
          stub_feature_flags(self_hosted_agent_platform: false)

          stub_request(:get, fetch_service_endpoint_url)
            .to_return(
              status: 200,
              body: model_definitions_response,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        it 'does not include model metadata headers' do
          get_response

          expect(response).to have_gitlab_http_status(:ok)

          headers = json_response['DuoWorkflow']['Headers']
          expect(headers).to include(
            'x-gitlab-oauth-token' => 'oauth_token',
            'x-gitlab-unidirectional-streaming' => 'enabled'
          )

          expect(headers).not_to have_key('x-gitlab-agent-platform-model-metadata')
        end

        it_behaves_like 'ServiceURI has the right value', false

        context 'when namespace params are provided' do
          let_it_be(:group) { create(:group) }

          context 'when a model selection setting exists' do
            let_it_be(:namespace_setting) do
              create(:ai_namespace_feature_setting,
                namespace: group,
                feature: :duo_agent_platform,
                offered_model_ref: 'claude_sonnet_3_7_20250219')
            end

            context 'when provided as param[:root_namespace_id]' do
              subject(:get_response) do
                get api(path, user), headers: workhorse_headers, params: { root_namespace_id: group.id }
              end

              it 'includes model metadata headers' do
                get_response

                expect(response).to have_gitlab_http_status(:ok)

                headers = json_response['DuoWorkflow']['Headers']
                expect(headers).to have_key('x-gitlab-agent-platform-model-metadata')

                metadata = ::Gitlab::Json.parse(headers['x-gitlab-agent-platform-model-metadata'])
                expect(metadata).to include(
                  'provider' => 'gitlab',
                  'feature_setting' => 'duo_agent_platform',
                  'identifier' => 'claude_sonnet_3_7_20250219'
                )
              end

              it_behaves_like 'ServiceURI has the right value', false

              context 'when user_selected_model_identifier is provided' do
                context 'when a valid user_selected_model_identifier is provided' do
                  let(:user_selected_model_identifier) { 'claude_sonnet_4_20250514' }

                  subject(:get_response) do
                    get api(path, user), headers: workhorse_headers, params: {
                      root_namespace_id: group.id,
                      user_selected_model_identifier: user_selected_model_identifier
                    }
                  end

                  it 'continues to use the namespace-level model selection' do
                    get_response

                    expect(response).to have_gitlab_http_status(:ok)

                    headers = json_response['DuoWorkflow']['Headers']
                    metadata = ::Gitlab::Json.parse(headers['x-gitlab-agent-platform-model-metadata'])
                    expect(metadata).to include(
                      'provider' => 'gitlab',
                      'feature_setting' => 'duo_agent_platform',
                      'identifier' => 'claude_sonnet_3_7_20250219'
                    )
                  end

                  it_behaves_like 'ServiceURI has the right value', false
                end
              end
            end

            context 'when provided as header[X-Gitlab-Namespace-Id]' do
              subject(:get_response) do
                get api(path, user), headers: workhorse_headers.merge('X-Gitlab-Namespace-Id' => group.id)
              end

              it 'includes model metadata headers' do
                get_response

                expect(response).to have_gitlab_http_status(:ok)

                headers = json_response['DuoWorkflow']['Headers']
                metadata = ::Gitlab::Json.parse(headers['x-gitlab-agent-platform-model-metadata'])
                expect(metadata).to include(
                  'provider' => 'gitlab',
                  'feature_setting' => 'duo_agent_platform',
                  'identifier' => 'claude_sonnet_3_7_20250219'
                )
              end

              it_behaves_like 'ServiceURI has the right value', false
            end
          end

          context 'when a model selection setting does not exist' do
            context 'when provided as param[:root_namespace_id]' do
              subject(:get_response) do
                get api(path, user), headers: workhorse_headers, params: { root_namespace_id: group.id }
              end

              it 'includes model metadata headers with default model' do
                get_response

                expect(response).to have_gitlab_http_status(:ok)

                headers = json_response['DuoWorkflow']['Headers']

                metadata = ::Gitlab::Json.parse(headers['x-gitlab-agent-platform-model-metadata'])
                expect(metadata).to include(
                  'provider' => 'gitlab',
                  'feature_setting' => 'duo_agent_platform',
                  'identifier' => nil
                )
              end

              it_behaves_like 'ServiceURI has the right value', false
            end

            context 'when a user_selected_model_identifier is provided' do
              subject(:get_response) do
                get api(path, user), headers: workhorse_headers, params: {
                  root_namespace_id: group.id,
                  user_selected_model_identifier: user_selected_model_identifier
                }
              end

              context 'when a valid user_selected_model_identifier is provided' do
                let(:user_selected_model_identifier) { 'claude_sonnet_4_20250514' }

                it 'uses the user-selected model' do
                  get_response

                  expect(response).to have_gitlab_http_status(:ok)

                  headers = json_response['DuoWorkflow']['Headers']
                  metadata = ::Gitlab::Json.parse(headers['x-gitlab-agent-platform-model-metadata'])
                  expect(metadata).to include(
                    'provider' => 'gitlab',
                    'feature_setting' => 'duo_agent_platform',
                    'identifier' => user_selected_model_identifier
                  )
                end

                it_behaves_like 'ServiceURI has the right value', false
              end

              context 'when an invalid user_selected_model_identifier is provided' do
                let(:user_selected_model_identifier) { 'invalid-model-for-duo-agent-platform' }

                it 'uses the default model' do
                  get_response

                  expect(response).to have_gitlab_http_status(:ok)

                  headers = json_response['DuoWorkflow']['Headers']
                  metadata = ::Gitlab::Json.parse(headers['x-gitlab-agent-platform-model-metadata'])
                  expect(metadata).to include(
                    'provider' => 'gitlab',
                    'feature_setting' => 'duo_agent_platform',
                    'identifier' => nil
                  )
                end

                it_behaves_like 'ServiceURI has the right value', false
              end

              context 'when an empty user_selected_model_identifier is provided' do
                let(:user_selected_model_identifier) { '' }

                it 'uses the default model' do
                  get_response

                  expect(response).to have_gitlab_http_status(:ok)

                  headers = json_response['DuoWorkflow']['Headers']
                  metadata = ::Gitlab::Json.parse(headers['x-gitlab-agent-platform-model-metadata'])
                  expect(metadata).to include(
                    'provider' => 'gitlab',
                    'feature_setting' => 'duo_agent_platform',
                    'identifier' => nil
                  )
                end

                it_behaves_like 'ServiceURI has the right value', false
              end

              context 'when user level model selection is disabled' do
                before do
                  stub_feature_flags(ai_user_model_switching: false)
                end

                context 'when a valid user_selected_model_identifier is provided' do
                  let(:user_selected_model_identifier) { 'claude_sonnet_4_20250514' }

                  it 'uses the default model' do
                    get_response

                    expect(response).to have_gitlab_http_status(:ok)

                    headers = json_response['DuoWorkflow']['Headers']
                    metadata = ::Gitlab::Json.parse(headers['x-gitlab-agent-platform-model-metadata'])
                    expect(metadata).to include(
                      'provider' => 'gitlab',
                      'feature_setting' => 'duo_agent_platform',
                      'identifier' => nil
                    )
                  end

                  it_behaves_like 'ServiceURI has the right value', false
                end
              end
            end
          end
        end
      end

      context 'when the duo_workflows and agentic_chat feature flag is disabled for the user' do
        before do
          stub_feature_flags(duo_workflow: false)
          stub_feature_flags(duo_agentic_chat: false)
        end

        it 'returns not found' do
          get_response

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when CreateOauthAccessTokenService returns an error' do
      before do
        allow_next_instance_of(::Ai::DuoWorkflows::CreateOauthAccessTokenService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.error(message: 'Failed to generate OAuth token', http_status: :unauthorized) # rubocop:disable Gitlab/ServiceResponse -- Preserve the actual behavior of the service response.
          )
        end
      end

      it 'returns an error response' do
        get api(path, user), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:unauthorized)
        expect(json_response['message']).to eq('Failed to generate OAuth token')
      end
    end

    context 'when Workhorse header is missing' do
      it 'returns an error response' do
        get api(path, user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when authenticated with a token that has the ai_workflows scope' do
      it 'is forbidden' do
        get api(path, oauth_access_token: ai_workflows_oauth_token), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'GET /ai/duo_workflows/list_tools' do
    let(:path) { '/ai/duo_workflows/list_tools' }

    let(:get_without_params) { get api(path, user) }
    let(:get_with_definition) { get api(path, user), params: { workflow_definition: workflow_definition } }

    before do
      allow(Gitlab.config.duo_workflow).to receive(:service_url).and_return duo_workflow_service_url
      stub_config(duo_workflow: {
        service_url: duo_workflow_service_url,
        secure: true
      })
    end

    context 'when the duo_workflows is disabled for the user' do
      before do
        stub_feature_flags(duo_workflow: false)
      end

      context 'when workflow_definition is software_developer' do
        let(:workflow_definition) { 'software_developer' }

        it 'returns not found' do
          get_with_definition

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when workflow_definition is chat' do
        let(:workflow_definition) { 'chat' }

        it 'process request further' do
          get_with_definition

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when workflow_definition is omitted' do
        it 'process request further' do
          get_without_params

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end

    context 'when agentic_chat feature flag is disabled for the user' do
      before do
        stub_feature_flags(duo_agentic_chat: false)
      end

      context 'when workflow_definition is chat' do
        let(:workflow_definition) { 'chat' }

        it 'returns not found' do
          get_with_definition

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when workflow_definition is software_developer' do
        let(:workflow_definition) { 'software_developer' }

        it 'process request further' do
          get_with_definition

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end

    context 'when the duo_workflows and agentic_chat feature flag is disabled for the user' do
      before do
        stub_feature_flags(duo_workflow: false)
        stub_feature_flags(duo_agentic_chat: false)
      end

      it 'returns not found' do
        get_without_params

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when rate limited' do
      it 'returns api error' do
        allow(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?).and_return(true)

        get_without_params

        expect(response).to have_gitlab_http_status(:too_many_requests)
        expect(response.headers)
          .to include('Retry-After' => Gitlab::ApplicationRateLimiter.interval(:duo_workflow_direct_access))
      end
    end

    context 'when DuoWorkflowService returns error' do
      it 'returns api error' do
        expect_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
          expect(client).to receive(:list_tools).and_return({
            status: :error,
            message: "could not list tools"
          })
        end

        get_without_params

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when success' do
      let(:payload) do
        {
          'tools' => [
            { 'name' => 'read_write_files' },
            { 'name' => 'run_commands' }
          ],
          'evalDataset' => [
            { 'tool_name' => 'read_write_files' }
          ]
        }
      end

      before do
        allow_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
          allow(client).to receive(:list_tools).and_return(ServiceResponse.success(payload: payload))
        end
      end

      it 'returns tools payload' do
        get_without_params

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq(payload)
      end

      context 'when authenticated with a token that has the ai_workflows scope' do
        it 'is forbidden' do
          get api(path, oauth_access_token: ai_workflows_oauth_token)

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end
  end

  describe 'GET /ai/duo_workflows/workflows/agent_privileges' do
    let(:path) { "/ai/duo_workflows/workflows/agent_privileges" }

    it 'returns a static set of privileges' do
      get api(path, user)

      expect(response).to have_gitlab_http_status(:ok)

      all_privileges_count = ::Ai::DuoWorkflows::Workflow::AgentPrivileges::ALL_PRIVILEGES.count
      expect(json_response['all_privileges'].count).to eq(all_privileges_count)

      privilege1 = json_response['all_privileges'][0]
      expect(privilege1['id']).to eq(1)
      expect(privilege1['name']).to eq('read_write_files')
      expect(privilege1['description']).to eq('Allow local filesystem read/write access')
      expect(privilege1['default_enabled']).to eq(true)

      privilege4 = json_response['all_privileges'][3]
      expect(privilege4['id']).to eq(4)
      expect(privilege4['name']).to eq('run_commands')
      expect(privilege4['description']).to eq('Allow running any commands')
      expect(privilege4['default_enabled']).to eq(false)
    end
  end
end
