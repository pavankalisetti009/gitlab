# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ai::DuoWorkflows::Workflows, feature_category: :duo_agent_platform do
  include HttpBasicAuthHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:user) { create(:user, maintainer_of: project) }
  let_it_be(:workflow) { create(:duo_workflows_workflow, user: user, project: project) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:duo_workflow_service_url) { 'duo-workflow-service.example.com:50052' }
  let_it_be(:ai_workflows_oauth_token) { create(:oauth_access_token, user: user, scopes: [:ai_workflows]) }
  let_it_be(:auth_response) { Ai::UserAuthorizable::Response.new(allowed?: true, namespace_ids: [group.id]) }
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
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(group, :duo_workflow).and_return(true)
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)

    allow_any_instance_of(User).to receive(:allowed_to_use).and_return(auth_response) # rubocop:disable RSpec/AnyInstanceOf -- not the next instance

    allow(::Ai::DuoWorkflow).to receive(:available?).and_return(true)

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
        environment: "web",
        ai_catalog_item_consumer_id: nil
      }.merge(container)
    end

    before do
      allow_next_instance_of(Ai::UsageQuotaService) do |instance|
        allow(instance).to receive(:execute).and_return(
          ServiceResponse.success
        )
      end
    end

    context 'when workflow is chat' do
      let_it_be(:default_organization) { create(:organization) }

      let(:workflow_definition) { 'chat' }

      before do
        allow(Gitlab::AiGateway).to receive(:public_headers)
          .with(user: user, ai_feature_name: :duo_workflow, unit_primitive_name: :duo_workflow_execute_workflow)
          .and_return({ 'x-gitlab-enabled-feature-flags' => 'test-feature' })
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :access_duo_agentic_chat, project).and_return(true)

        allow(::Organizations::Organization).to receive(:default_organization).and_return(default_organization)
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

      context 'when neither project_id nor namespace_id are specified' do
        let(:container) { {} }

        context 'when user has a default duo namespace' do
          let(:default_namespace) { create(:group) }

          before do
            default_namespace.add_developer(user)
            allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(default_namespace,
              :agentic_chat).and_return(true)
            user.user_preference.update!(duo_default_namespace_id: default_namespace.id)
            allow(Ability).to receive(:allowed?).and_call_original
            allow(Ability).to receive(:allowed?).with(user, :access_duo_agentic_chat,
              default_namespace).and_return(true)
          end

          it 'creates a workflow using the default namespace' do
            post api(path, user), params: params

            expect(response).to have_gitlab_http_status(:created)
            created_workflow = Ai::DuoWorkflows::Workflow.last
            expect(json_response['id']).to eq(created_workflow.id)
            expect(json_response['namespace_id']).to eq(default_namespace.id)
            expect(json_response['project_id']).to be_nil
          end
        end

        context 'when user has no default duo namespace' do
          before do
            allow_any_instance_of(UserPreference).to receive(:duo_default_namespace_with_fallback).and_return(nil) # rubocop:disable RSpec/AnyInstanceOf -- user is reloaded during request
          end

          it 'returns error' do
            post api(path, user), params: params

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(response.body).to include('No default namespace found')
          end
        end

        context 'when user cannot access their default duo namespace' do
          let(:inaccessible_namespace) { create(:group, :private) }

          before do
            # User is NOT a member of this private namespace
            allow_any_instance_of(UserPreference).to receive(:duo_default_namespace_with_fallback).and_return(inaccessible_namespace) # rubocop:disable RSpec/AnyInstanceOf -- user is reloaded during request
          end

          it 'returns forbidden error' do
            post api(path, user), params: params

            expect(response).to have_gitlab_http_status(:forbidden)
            expect(response.body).to include('Access to the container is not allowed')
          end
        end
      end

      context 'when both project_id and namespace_id are specified' do
        let(:container) { { project_id: project.id, namespace_id: group.id } }

        it 'uses project_id and ignores namespace_id' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:created)

          created_workflow = Ai::DuoWorkflows::Workflow.last
          expect(json_response['id']).to eq(created_workflow.id)
          expect(json_response['project_id']).to eq(created_workflow.project.id)
          expect(json_response['project_id']).to eq(project.id)
          expect(json_response['namespace_id']).to be_nil
        end
      end

      context 'when project_id does not exist' do
        let(:container) { { project_id: non_existing_record_id } }

        it 'returns not found error' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when namespace_id does not exist' do
        let(:container) { { namespace_id: non_existing_record_id } }

        it 'returns not found error' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:not_found)
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
            [
              Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES,
              Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_GITLAB
            ]
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

      context 'when issue_id is provided' do
        let(:params) { { project_id: project.id, issue_id: issue.iid } }

        it 'creates a workflow associated with the issue' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
          created_workflow = Ai::DuoWorkflows::Workflow.last
          expect(created_workflow.issue).to eq(issue)
          expect(created_workflow.merge_request).to be_nil
        end
      end

      context 'when no issue_id is provided' do
        let(:params) { { project_id: project.id, issue_id: nil } }

        it 'creates a workflow without issue association' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
          created_workflow = Ai::DuoWorkflows::Workflow.last
          expect(created_workflow.issue).to be_nil
        end
      end

      context 'when merge_request_id is provided' do
        let(:params) { { project_id: project.id, merge_request_id: merge_request.iid } }

        it 'creates a workflow associated with the merge request' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
          created_workflow = Ai::DuoWorkflows::Workflow.last
          expect(created_workflow.merge_request).to eq(merge_request)
          expect(created_workflow.issue).to be_nil
        end
      end

      context 'when no merge_request_id is provided' do
        let(:params) { { project_id: project.id, merge_request_id: nil } }

        it 'creates a workflow without merge request association' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
          created_workflow = Ai::DuoWorkflows::Workflow.last
          expect(created_workflow.merge_request).to be_nil
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

      context 'when duo_features_enabled settings is turned off' do
        before do
          project.project_setting.update!(duo_features_enabled: false)
          project.reload
        end

        it_behaves_like 'workflow access is forbidden'
      end

      context 'when there are not enough credits' do
        before do
          allow_next_instance_of(Ai::UsageQuotaService) do |instance|
            allow(instance).to receive(:execute).and_return(
              ServiceResponse.error(message: "Usage quota exceeded", reason: :usage_quota_exceeded)
            )
          end
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

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(json_response['message']).to eq('Can not execute workflow in CI')
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

      context 'when tracking internal events for SAST vulnerability FP detection' do
        let_it_be(:vulnerability) { create(:vulnerability, project: project) }
        let(:params) do
          {
            project_id: project.id,
            start_workflow: true,
            goal: vulnerability.id.to_s,
            workflow_definition: ::Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker::WORKFLOW_DEFINITION
          }
        end

        it 'tracks the event with correct properties' do
          allow(Gitlab::InternalEvents).to receive(:track_event).and_call_original

          expect(Gitlab::InternalEvents).to receive(:track_event).with(
            'trigger_sast_vulnerability_fp_detection_workflow',
            hash_including(
              project: project,
              additional_properties: {
                label: 'manual',
                value: vulnerability.id,
                property: vulnerability.severity
              }
            )
          ).and_call_original

          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
        end

        context 'when vulnerability does not exist' do
          let(:params) do
            {
              project_id: project.id,
              start_workflow: true,
              goal: non_existing_record_id.to_s,
              workflow_definition: ::Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker::WORKFLOW_DEFINITION
            }
          end

          it 'does not track the event' do
            expect(Gitlab::InternalEvents).not_to receive(:track_event).with(
              'trigger_sast_vulnerability_fp_detection_workflow',
              anything
            )

            post api(path, user), params: params
          end
        end

        context 'when workflow_definition is not for SAST FP detection' do
          let(:params) do
            {
              project_id: project.id,
              start_workflow: true,
              goal: vulnerability.id.to_s,
              workflow_definition: 'software_development'
            }
          end

          it 'does not track the event' do
            expect(Gitlab::InternalEvents).not_to receive(:track_event).with(
              'trigger_sast_vulnerability_fp_detection_workflow',
              anything
            )

            post api(path, user), params: params
          end
        end

        context 'when start_workflow is not present' do
          let(:params) do
            {
              project_id: project.id,
              goal: vulnerability.id.to_s,
              workflow_definition: ::Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker::WORKFLOW_DEFINITION
            }
          end

          it 'does not track the event' do
            expect(Gitlab::InternalEvents).not_to receive(:track_event).with(
              'trigger_sast_vulnerability_fp_detection_workflow',
              anything
            )

            post api(path, user), params: params
          end
        end
      end

      context 'when tracking internal events for SAST vulnerability resolution' do
        let_it_be(:vulnerability) { create(:vulnerability, project: project) }
        let(:params) do
          {
            project_id: project.id,
            start_workflow: true,
            goal: vulnerability.id.to_s,
            workflow_definition: ::Vulnerabilities::TriggerResolutionWorkflowWorker::WORKFLOW_DEFINITION
          }
        end

        it 'tracks the event with correct properties' do
          expect { post api(path, user), params: params }
            .to trigger_internal_events('trigger_sast_vulnerability_resolution_workflow')
                  .with(project: project,
                    category: 'InternalEventTracking',
                    additional_properties: {
                      label: 'manual',
                      value: vulnerability.id,
                      property: vulnerability.severity
                    }
                  )
                  .and increment_usage_metrics('counts.count_total_trigger_sast_vulnerability_resolution_workflow')

          expect(response).to have_gitlab_http_status(:created)
        end

        context 'when vulnerability does not exist' do
          let(:params) do
            {
              project_id: project.id,
              start_workflow: true,
              goal: non_existing_record_id.to_s,
              workflow_definition: ::Vulnerabilities::TriggerResolutionWorkflowWorker::WORKFLOW_DEFINITION
            }
          end

          it 'does not track the event' do
            expect { post api(path, user), params: params }
              .not_to trigger_internal_events('trigger_sast_vulnerability_resolution_workflow')
          end
        end

        context 'when workflow_definition is not for SAST resolution' do
          let(:params) do
            {
              project_id: project.id,
              start_workflow: true,
              goal: vulnerability.id.to_s,
              workflow_definition: 'software_development'
            }
          end

          it 'does not track the event' do
            expect { post api(path, user), params: params }
              .not_to trigger_internal_events('trigger_sast_vulnerability_resolution_workflow')
          end
        end

        context 'when start_workflow is not present' do
          let(:params) do
            {
              project_id: project.id,
              goal: vulnerability.id.to_s,
              workflow_definition: ::Vulnerabilities::TriggerResolutionWorkflowWorker::WORKFLOW_DEFINITION
            }
          end

          it 'does not track the event' do
            expect { post api(path, user), params: params }
              .not_to trigger_internal_events('trigger_sast_vulnerability_resolution_workflow')
          end
        end
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
          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['message']).to eq('Error in creating workload: full error messages')
        end
      end

      context 'when branch creation fails during CI execution' do
        let(:params) do
          {
            project_id: project.id,
            start_workflow: true,
            goal: 'Print hello world',
            source_branch: 'feature-branch'
          }
        end

        before do
          allow_next_instance_of(Ci::Workloads::RunWorkloadService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Error in git branch creation')
            )
          end
        end

        it 'returns error message about branch creation failure' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['message']).to eq('Error in git branch creation')
        end
      end

      context 'when start workflow service returns :unprocessable_entity error' do
        let(:params) do
          {
            project_id: project.id,
            start_workflow: true,
            goal: 'Print hello world'
          }
        end

        before do
          allow_next_instance_of(::Ai::DuoWorkflows::StartWorkflowService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Unprocessable entity error', reason: :unprocessable_entity)
            )
          end
        end

        it 'returns HTTP 422 status code' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['message']).to eq('Unprocessable entity error')
        end
      end

      context 'when start workflow service returns unmapped error reason' do
        let(:params) do
          {
            project_id: project.id,
            start_workflow: true,
            goal: 'Print hello world'
          }
        end

        before do
          allow_next_instance_of(::Ai::DuoWorkflows::StartWorkflowService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Unknown error occurred', reason: :unknown_error)
            )
          end
        end

        it 'returns HTTP 500 status code as default fallback' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:internal_server_error)
          expect(json_response['message']).to eq('Unknown error occurred')
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
          # TODO: use factory instead https://gitlab.com/gitlab-org/gitlab/-/issues/583818
          allow(::Ai::DuoWorkflow).to receive(:duo_agent_platform_available?).and_return(true)
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

      context 'when workflow_definition is a foundational flow' do
        let_it_be(:foundational_flow_group) { create(:group) }
        let_it_be(:foundational_flow_service_account) do
          create(:user, :service_account,
            composite_identity_enforced: true,
            provisioned_by_group: foundational_flow_group
          )
        end

        let_it_be(:foundational_flow_item) do
          create(:ai_catalog_item, :flow, foundational_flow_reference: 'fix_pipeline/v1')
        end

        let_it_be(:foundational_flow_consumer) do
          create(:ai_catalog_item_consumer,
            item: foundational_flow_item,
            group: foundational_flow_group,
            service_account: foundational_flow_service_account
          )
        end

        let_it_be(:foundational_flow_project) do
          create(:project, :repository, group: foundational_flow_group, developers: user)
        end

        before_all do
          foundational_flow_group.add_developer(user)
          foundational_flow_project.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)
        end

        before do
          allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_call_original
          allow(::Gitlab::Llm::StageCheck).to receive(:available?)
                                                .with(foundational_flow_project, :duo_workflow).and_return(true)
        end

        context 'when service account is resolved from catalog item consumer' do
          let(:params) do
            {
              project_id: foundational_flow_project.id,
              workflow_definition: 'fix_pipeline/v1',
              goal: 'Fix the pipeline',
              start_workflow: true
            }
          end

          it 'creates a workflow with the resolved service_account_id' do
            post api(path, user), params: params

            expect(response).to have_gitlab_http_status(:created)
            created_workflow = Ai::DuoWorkflows::Workflow.last
            expect(created_workflow.service_account_id).to eq(foundational_flow_service_account.id)
          end

          it 'passes the resolved service_account to CreateWorkflowService' do
            expect(::Ai::DuoWorkflows::CreateWorkflowService).to receive(:new).with(
              hash_including(
                params: hash_including(service_account: foundational_flow_service_account)
              )
            ).and_call_original

            post api(path, user), params: params

            expect(response).to have_gitlab_http_status(:created)
          end
        end
      end

      context 'when workflow_definition is not a foundational flow' do
        let(:params) do
          {
            project_id: project.id,
            workflow_definition: 'custom_flow',
            goal: 'Implement a cool feature',
            start_workflow: true
          }
        end

        it 'creates a workflow without resolving service_account_id from catalog item consumer' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
          created_workflow = Ai::DuoWorkflows::Workflow.last
          expect(created_workflow.service_account_id).to be_nil
        end

        it 'does not pass service_account to CreateWorkflowService' do
          expect(::Ai::DuoWorkflows::CreateWorkflowService).to receive(:new).with(
            hash_including(
              params: hash_not_including(:service_account)
            )
          ).and_call_original

          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:created)
        end
      end

      context 'when foundational flow has no consumer configured' do
        let_it_be(:no_consumer_project) { create(:project, :repository, developers: user) }
        let_it_be(:no_consumer_catalog_item) do
          create(:ai_catalog_item, :flow, foundational_flow_reference: 'fix_pipeline/v1')
        end

        let(:params) do
          {
            project_id: no_consumer_project.id,
            workflow_definition: 'fix_pipeline/v1',
            goal: 'Fix the pipeline',
            start_workflow: true
          }
        end

        before do
          no_consumer_project.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)
          allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_call_original
          allow(::Gitlab::Llm::StageCheck).to receive(:available?)
                                                .with(no_consumer_project, :duo_workflow).and_return(true)
        end

        it 'returns an error when service account cannot be resolved' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(json_response['message']).to match(/No item consumer found|service account/)
        end
      end

      context 'when ai_catalog_item_consumer_id is provided' do
        let_it_be(:consumer_group) { create(:group) }
        let_it_be(:flow_project) { create(:project, group: consumer_group) }
        let_it_be(:flow) { create(:ai_catalog_flow, :public, project: flow_project) }

        let_it_be(:consumer_service_account) do
          create(:user, :service_account,
            composite_identity_enforced: true,
            provisioned_by_group: consumer_group
          )
        end

        let_it_be(:group_consumer) do
          create(:ai_catalog_item_consumer,
            item: flow,
            group: consumer_group,
            service_account: consumer_service_account
          )
        end

        let_it_be(:execution_project) do
          create(:project, :repository, group: consumer_group, developers: user)
        end

        let_it_be(:project_consumer) do
          create(:ai_catalog_item_consumer,
            item: flow,
            project: execution_project,
            parent_item_consumer: group_consumer
          )
        end

        before_all do
          consumer_group.add_developer(user)
          execution_project.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)
          flow_project.update!(duo_features_enabled: true)
        end

        before do
          allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_call_original
          allow(::Gitlab::Llm::StageCheck).to receive(:available?)
                                                .with(flow_project, :ai_catalog).and_return(true)
          allow(::Gitlab::Llm::StageCheck).to receive(:available?)
                                                .with(execution_project, :ai_catalog).and_return(true)
          allow(::Gitlab::Llm::StageCheck).to receive(:available?)
                                                .with(execution_project, :duo_workflow).and_return(true)

          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?)
                              .with(user, :execute_ai_catalog_item_version, anything)
                              .and_return(true)
        end

        it 'executes the AI catalog flow with correct service account' do
          fake_workflow = build(:duo_workflows_workflow, id: 180, user: user, project: execution_project)

          expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
            project: execution_project,
            current_user: user,
            params: hash_including(
              item_consumer: project_consumer,
              service_account: consumer_service_account,
              execute_workflow: true,
              event_type: 'api_execution',
              user_prompt: 'Execute catalog flow',
              source_branch: 'master',
              additional_context: [{
                Category: "agent_user_environment",
                Content: "some content",
                Metadata: "{}"
              }]
            )
          ).and_return(
            instance_double(
              Ai::Catalog::Flows::ExecuteService,
              execute: ServiceResponse.success(
                payload: { workflow: fake_workflow, workload_id: 123 }
              )
            )
          )

          post api("/ai/duo_workflows/workflows", user), params: {
            project_id: execution_project.id,
            ai_catalog_item_consumer_id: project_consumer.id,
            start_workflow: true,
            goal: 'Execute catalog flow',
            source_branch: 'master',
            additional_context: [{
              Category: "agent_user_environment",
              Content: "some content",
              Metadata: "{}"
            }]
          }

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['workload']['id']).to eq(123)
        end

        it 'returns forbidden when consumer does not belong to project' do
          # Create consumer for a different project entirely
          other_project = create(:project)
          other_flow = create(:ai_catalog_flow, :public, project: other_project)
          other_consumer = create(:ai_catalog_item_consumer,
            item: other_flow,
            project: other_project
          )

          post api("/ai/duo_workflows/workflows", user), params: {
            project_id: execution_project.id,
            ai_catalog_item_consumer_id: other_consumer.id,
            start_workflow: true,
            goal: 'test'
          }

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(json_response['message']).to include('AI Catalog Item Consumer does not belong to this project')
        end

        it 'returns not found when consumer does not exist' do
          post api("/ai/duo_workflows/workflows", user), params: {
            project_id: execution_project.id,
            ai_catalog_item_consumer_id: non_existing_record_id,
            start_workflow: true,
            goal: 'test'
          }

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to include('AI Catalog Item Consumer not found')
        end

        it 'returns bad request when used in namespace context' do
          post api("/ai/duo_workflows/workflows", user), params: {
            namespace_id: consumer_group.id,
            ai_catalog_item_consumer_id: project_consumer.id,
            start_workflow: true,
            goal: 'test'
          }

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(response.body).to include('AI Catalog flows can only be executed in project context')
        end
      end

      context 'when OAuth token creation fails' do
        before do
          allow_next_instance_of(::Ai::DuoWorkflows::WorkflowContextGenerationService) do |service|
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
        context 'with usage quota exceeded error code' do
          before do
            allow_next_instance_of(::Ai::DuoWorkflows::WorkflowContextGenerationService) do |service|
              allow(service).to receive(:generate_workflow_token)
                .and_return(ServiceResponse.error(message: 'Consumer does not have sufficient ' \
                                                    'credits for this request. Error code: USAGE_QUOTA_EXCEEDED'))
            end
          end

          it 'returns forbidden with specific message' do
            post api(path, user), params: params

            expect(response).to have_gitlab_http_status(:forbidden)
            expect(json_response['message']).to eq(
              "You don't have enough GitLab Credits to run this flow. Contact your " \
                "administrator for more credits."
            )
          end
        end

        context 'with any other error' do
          before do
            allow_next_instance_of(::Ai::DuoWorkflows::WorkflowContextGenerationService) do |service|
              allow(service).to receive(:generate_workflow_token)
                                  .and_return(ServiceResponse.error(message: 'workflow token creation failed'))
            end
          end

          it 'returns api error' do
            post api(path, user), params: params

            expect(response).to have_gitlab_http_status(:bad_request)
          end
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

      context 'when composite identity onboarding is incomplete' do
        before do
          allow(::Ai::DuoWorkflow).to receive(:available?).and_return(false)
        end

        it 'returns forbidden error with link to documentation' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(json_response['message']).to eq(
            'GitLab Duo Agent Platform onboarding is incomplete, composite identity must be enabled. ' \
              '<a href="https://docs.gitlab.com/administration/gitlab_duo/configure/' \
              'gitlab_self_managed/#turn-on-composite-identity">' \
              'Learn more</a>'
          )
        end
      end
    end
  end

  describe 'POST /ai/duo_workflows/direct_access' do
    let(:path) { '/ai/duo_workflows/direct_access' }

    let(:post_without_params) { post api(path, user) }
    let(:post_with_definition) { post api(path, user), params: { workflow_definition: workflow_definition } }

    let(:post_with_params) do
      post api(path, user), params: { workflow_definition: workflow_definition, root_namespace_id: namespace_id }
    end

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

    shared_context 'when tokens are generated' do
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

        allow(::Gitlab::SubscriptionPortal::Client).to receive(:verify_usage_quota).and_return({ success: true })
      end
    end

    shared_context 'when usage quota check passes' do
      before do
        allow_next_instance_of(::Ai::UsageQuotaService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success)
        end
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

    context 'when root_namespace_id params is not passed' do
      context 'when on SaaS' do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)

          allow_next_instance_of(::Ai::UsageQuotaService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'Namespace is required'))
          end
        end

        it 'returns error that root_namespace_id is required' do
          post_with_definition

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(json_response['message']).to include('Namespace is required')
        end

        context 'when feature flag is disabled' do
          before do
            stub_feature_flags(usage_quota_check_in_direct_access: false)
          end

          include_context 'when tokens are generated'

          it 'generates token if feature flag is disabled' do
            stub_feature_flags(usage_quota_check_in_direct_access: false)

            post_with_definition

            expect(response).to have_gitlab_http_status(:created)
          end
        end
      end

      context 'when on Self-managed instance' do
        include_context 'when tokens are generated'

        it 'successfully generates a direct access token' do
          post_with_definition

          expect(response).to have_gitlab_http_status(:created)
        end
      end
    end

    context 'when CreateOauthAccessTokenService returns error' do
      include_context 'when usage quota check passes'

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
      include_context 'when usage quota check passes'

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

    context 'when usage quota check fails' do
      before do
        allow_next_instance_of(::Ai::UsageQuotaService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.error(message: 'Usage quota exceeded', reason: :usage_quota_exceeded)
          )
        end
      end

      it 'returns error that root_namespace_id is required' do
        post_with_definition

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response['message']).to include('USAGE_QUOTA_EXCEEDED: Usage quota exceeded')
      end
    end

    context 'when workflow_definition param is passed' do
      context 'when it is chat' do
        let(:workflow_definition) { "chat" }

        it 'calls usage quota service for chat feature' do
          expect(::Ai::UsageQuotaService).to receive(:new)
            .with(ai_feature: :duo_chat, user: user, namespace: nil)

          post_with_definition
        end
      end

      context 'when it is not chat' do
        let(:workflow_definition) { "software_development" }

        it 'calls usage quota service for duo_agent_platform feature' do
          expect(::Ai::UsageQuotaService).to receive(:new)
            .with(ai_feature: :duo_agent_platform, user: user, namespace: nil)

          post_with_definition
        end
      end
    end

    context 'when success' do
      let(:namespace_id) { group.id }

      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      include_context 'when tokens are generated'

      it 'returns access payload' do
        post_with_params

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

    subject(:get_response) { get api(path, user), headers: workhorse_headers, params: { workflow_definition: 'chat' } }

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
            expect(json_response['DuoWorkflow']['Service']['URI']).to eq(self_hosted_duo_workflow_service_url)
          else
            expect(json_response['DuoWorkflow']['Service']['URI']).to eq(duo_workflow_service_url)
          end
        end
      end

      context 'with no duo workflow service url set' do
        let(:duo_workflow_service_url) { nil }

        it 'routes to the right service uri' do
          get_response

          if with_self_hosted_setting
            expect(json_response['DuoWorkflow']['Service']['URI']).to eq(self_hosted_duo_workflow_service_url)
          else
            expect(json_response['DuoWorkflow']['Service']['URI']).to eq(default_duo_workflow_service_url)
          end
        end
      end
    end

    context 'when user is authenticated' do
      it 'returns the websocket configuration with proper headers' do
        get_response

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.media_type).to eq(Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE)

        enabled_mcp_tools = ::Ai::DuoWorkflows::McpConfigService::GITLAB_ENABLED_TOOLS
        preapproved_mcp_tools = ::Ai::DuoWorkflows::McpConfigService::GITLAB_PREAPPROVED_TOOLS
        expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
          'x-gitlab-oauth-token' => 'oauth_token',
          'authorization' => 'Bearer token',
          'x-gitlab-authentication-type' => 'oidc',
          'x-gitlab-enabled-feature-flags' => anything,
          'x-gitlab-instance-id' => anything,
          'x-gitlab-version' => Gitlab.version_info.to_s,
          'x-gitlab-unidirectional-streaming' => 'enabled',
          'x-gitlab-enabled-mcp-server-tools' => enabled_mcp_tools.join(','),
          'x-gitlab-model-prompt-cache-enabled' => 'false'
        )

        expect(json_response['DuoWorkflow']['Service']['Secure']).to eq(true)
        expect(json_response['DuoWorkflow']['LockConcurrentFlow']).to eq(true)
        expect(json_response['DuoWorkflow']['McpServers']).to eq({
          "gitlab" => {
            "Headers" => {
              "Authorization" => "Bearer oauth_token"
            },
            "PreApprovedTools" => preapproved_mcp_tools,
            "Tools" => enabled_mcp_tools
          }
        })
        expect(json_response['DuoWorkflow']['ServerCapabilities']).to eq([])
      end

      context 'for ServerCapabilities' do
        context 'when advanced search is enabled for the project' do
          before do
            allow(::Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?)
              .with(scope: project).and_return(true)
          end

          it 'returns advanced_search capability' do
            get api(path, user), headers: workhorse_headers, params: { project_id: project.id }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['DuoWorkflow']['ServerCapabilities']).to eq(['advanced_search'])
          end
        end

        context 'when advanced search is disabled' do
          before do
            allow(::Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).and_return(false)
          end

          it 'returns empty capabilities' do
            get api(path, user), headers: workhorse_headers, params: { project_id: project.id }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['DuoWorkflow']['ServerCapabilities']).to eq([])
          end
        end

        context 'when namespace_id is provided instead of project_id' do
          before do
            allow(::Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?)
                                                  .with(scope: group).and_return(true)
          end

          it 'checks advanced search for the namespace' do
            get api(path, user), headers: workhorse_headers, params: { namespace_id: group.id }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['DuoWorkflow']['ServerCapabilities']).to eq(['advanced_search'])
          end
        end

        context 'when namespace is provided via header' do
          before do
            allow(::Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?)
                                                  .with(scope: group).and_return(true)
          end

          it 'checks advanced search for the namespace from header' do
            get api(path, user), headers: workhorse_headers.merge('X-Gitlab-Namespace-Id' => group.id)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['DuoWorkflow']['ServerCapabilities']).to eq(['advanced_search'])
          end
        end
      end

      context 'when self-hosted DAP billing is enabled for the feature' do
        before do
          allow(Ai::SelfHostedDapBilling).to receive(:should_bill?).and_return(true)
          allow(::CloudConnector::Tokens).to receive(:cloud_connector_token).and_return('cloud_connector_token')
        end

        it 'populates CloudServiceForSelfHosted with Cloud Connector values' do
          get_response

          expect(response).to have_gitlab_http_status(:ok)

          cloud_service = json_response['DuoWorkflow']['CloudServiceForSelfHosted']
          expect(cloud_service['URI']).to eq(Gitlab::DuoWorkflow::Client.cloud_connected_url(user: user))
          expect(cloud_service['Headers']).to be_present
          expect(cloud_service['Headers']).to include('authorization' => "Bearer cloud_connector_token")
          expect(cloud_service['Secure']).to be(true)
        end

        it 'includes project and client type context in CloudServiceForSelfHosted headers' do
          get api(path, user),
            headers: workhorse_headers,
            params: { workflow_definition: 'chat', project_id: project.id, client_type: 'web' }

          expect(response).to have_gitlab_http_status(:ok)

          cloud_service = json_response['DuoWorkflow']['CloudServiceForSelfHosted']
          expect(cloud_service['Headers']).to include(
            'x-gitlab-project-id' => project.id.to_s,
            'x-gitlab-client-type' => 'web'
          )
        end
      end

      context 'when self-hosted DAP billing is disabled for the feature' do
        before do
          allow(Ai::SelfHostedDapBilling).to receive(:should_bill?).and_return(false)
        end

        it 'omits CloudServiceForSelfHosted config' do
          get_response

          expect(response).to have_gitlab_http_status(:ok)

          cloud_service = json_response['DuoWorkflow']['CloudServiceForSelfHosted']
          expect(cloud_service).to be_nil
        end
      end

      context 'when workflow_definition is for agentic chat' do
        it 'includes MCP server configuration' do
          get api(path, user), headers: workhorse_headers, params: { workflow_definition: 'chat' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['McpServers']).to be_present
          expect(json_response['DuoWorkflow']['Service']['Headers']['x-gitlab-enabled-mcp-server-tools']).to be_present
        end
      end

      context 'when workflow_definition is for a foundational agent' do
        it 'does not include MCP server configuration' do
          get api(path, user), headers: workhorse_headers, params: { workflow_definition: 'software_development' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['McpServers']).to be_nil
          expect(json_response['DuoWorkflow']['Service']['Headers']['x-gitlab-enabled-mcp-server-tools']).to eq('')
        end
      end

      it_behaves_like 'ServiceURI has the right value', false

      context 'when current_user is a composite identity user' do
        let_it_be(:service_account) { create(:service_account, composite_identity_enforced: true) }
        let_it_be(:scopes) { ::Gitlab::Auth::AI_WORKFLOW_SCOPES + ['api'] + ["user:#{user.id}"] }
        let_it_be(:oauth_access_token) { create(:oauth_access_token, resource_owner: service_account, scopes: scopes) }

        it 'generates a token using the correct service account' do
          expect(::Ai::DuoWorkflows::WorkflowContextGenerationService).to receive(:new).with(
            a_hash_including(service_account: have_attributes(id: service_account.id))
          ).and_call_original

          get api(path, oauth_access_token:), headers: workhorse_headers, params: { project_id: project.id }

          expect(response).to have_gitlab_http_status(:ok)
        end

        context 'and namespace is specified' do
          let_it_be(:group) { create(:group, :private) }
          let_it_be(:project) { create(:project, :repository, group: group) }

          it 'is successful' do
            project.add_developer(service_account)
            group.add_developer(user)

            get api(path, oauth_access_token:), headers: workhorse_headers,
              params: { project_id: project.id, namespace_id: group.id, root_namespace_id: group.root_ancestor.id }

            expect(response).to have_gitlab_http_status(:ok)
          end
        end
      end

      context 'when project_id parameter is provided' do
        it 'includes x-gitlab-project-id header' do
          get api(path, user), headers: workhorse_headers, params: { project_id: project.id }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
            'x-gitlab-project-id' => project.id.to_s
          )
        end

        it 'sets x-gitlab-project-id header to nil when project_id is blank' do
          get api(path, user), headers: workhorse_headers, params: { project_id: '' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Service']['Headers']['x-gitlab-project-id']).to be_nil
        end
      end

      context 'when X-Gitlab-Language-Server-Version header is provided' do
        it 'includes x-gitlab-language-server-version header' do
          get api(path, user), headers: workhorse_headers.merge('X-Gitlab-Language-Server-Version': "8.22.0"),
            params: { project_id: project.id }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
            'x-gitlab-language-server-version' => "8.22.0"
          )
        end

        it 'does not include x-gitlab-language-server-version header when header is not provided' do
          get api(path, user), headers: workhorse_headers, params: { project_id: project.id }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Service']['Headers']['x-gitlab-language-server-version']).to be_nil
        end
      end

      context 'for X-Gitlab-Client-Type header' do
        it 'sends x-gitlab-client-type gRPC header when http request have X-Gitlab-Client-Type header' do
          get api(path, user), headers: workhorse_headers.merge('X-Gitlab-Client-Type': "node-websocket"),
            params: { project_id: project.id }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
            'x-gitlab-client-type' => "node-websocket"
          )
        end

        it 'sends x-gitlab-client-type gRPC header when http request have client_type param' do
          get api(path, user), headers: workhorse_headers,
            params: { project_id: project.id, client_type: 'browser' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
            'x-gitlab-client-type' => "browser"
          )
        end

        it 'does not include x-gitlab-client-type header when neither header nor param is provided' do
          get api(path, user), headers: workhorse_headers, params: { project_id: project.id }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Service']['Headers']['x-gitlab-client-type']).to be_nil
        end
      end

      context 'when namespace_id parameter is provided' do
        it 'includes x-gitlab-namespace-id header' do
          get api(path, user), headers: workhorse_headers, params: { namespace_id: group.id }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
            'x-gitlab-namespace-id' => group.id.to_s
          )
        end

        it 'falls back to X-Gitlab-Namespace-Id header when namespace_id is blank' do
          get api(path, user), headers: workhorse_headers.merge('X-Gitlab-Namespace-Id' => group.id),
            params: { namespace_id: '' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
            'x-gitlab-namespace-id' => group.id.to_s,
            'x-gitlab-root-namespace-id' => group.id.to_s
          )
        end
      end

      context 'when root_namespace_id parameter is provided' do
        it 'includes x-gitlab-root-namespace-id header and sets namespace-id to root' do
          get api(path, user), headers: workhorse_headers, params: { root_namespace_id: group.id }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
            'x-gitlab-root-namespace-id' => group.id.to_s,
            'x-gitlab-namespace-id' => group.id.to_s
          )
        end

        it 'uses default value when namespace is not found' do
          get api(path, user), headers: workhorse_headers, params: { root_namespace_id: 99999 }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
            'x-gitlab-root-namespace-id' => group.id.to_s,
            'x-gitlab-namespace-id' => group.id.to_s
          )
        end
      end

      context 'when both project_id and namespace_id parameters are provided' do
        it 'includes both x-gitlab-project-id and x-gitlab-namespace-id headers' do
          get api(path, user), headers: workhorse_headers, params: {
            project_id: project.id,
            namespace_id: group.id
          }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
            'x-gitlab-project-id' => project.id.to_s,
            'x-gitlab-namespace-id' => group.id.to_s
          )
        end
      end

      context 'when namespace is provided via X-Gitlab-Namespace-Id header' do
        it 'includes x-gitlab-namespace-id header in response' do
          get api(path, user), headers: workhorse_headers.merge('X-Gitlab-Namespace-Id' => group.id)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
            'x-gitlab-namespace-id' => group.id.to_s
          )
        end
      end

      context 'when precedence of namespace parameters is tested' do
        let_it_be(:child_group) { create(:group, parent: group) }
        let_it_be(:auth_response) do
          Ai::UserAuthorizable::Response.new(allowed?: true, namespace_ids: [group.id, child_group.id])
        end

        it 'sets both root and namespace headers, with namespace_id taking precedence for x-gitlab-namespace-id' do
          get api(path, user), headers: workhorse_headers.merge('X-Gitlab-Namespace-Id' => child_group.id), params: {
            root_namespace_id: group.id,
            namespace_id: child_group.id
          }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
            'x-gitlab-root-namespace-id' => group.id.to_s,
            'x-gitlab-namespace-id' => child_group.id.to_s
          )
        end

        it 'uses namespace_id parameter over X-Gitlab-Namespace-Id header when root_namespace_id is not provided' do
          get api(path, user), headers: workhorse_headers.merge('X-Gitlab-Namespace-Id' => group.id), params: {
            namespace_id: child_group.id
          }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
            'x-gitlab-namespace-id' => child_group.id.to_s,
            'x-gitlab-root-namespace-id' => child_group.root_ancestor.id.to_s
          )
        end

        it 'falls back to X-Gitlab-Namespace-Id header when no namespace params are provided' do
          get api(path, user), headers: workhorse_headers.merge('X-Gitlab-Namespace-Id' => group.id)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
            'x-gitlab-namespace-id' => group.id.to_s,
            'x-gitlab-root-namespace-id' => group.id.to_s
          )
        end

        it 'uses root_namespace_id for x-gitlab-namespace-id when only root_namespace_id is provided' do
          get api(path, user), headers: workhorse_headers.merge('X-Gitlab-Namespace-Id' => child_group.id), params: {
            root_namespace_id: group.id
          }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
            'x-gitlab-root-namespace-id' => group.id.to_s,
            'x-gitlab-namespace-id' => group.id.to_s
          )
        end
      end

      # rubocop:disable RSpec/MultipleMemoizedHelpers -- Complex authorization test requires multiple groups, projects, and namespaces to validate security boundaries
      context 'with namespace authorization and context validation' do
        let_it_be(:other_group) { create(:group) }
        let_it_be(:other_project) { create(:project, :repository, group: other_group) }
        let_it_be(:unauthorized_group) { create(:group, :private) }
        let_it_be(:parent_group_2) { create(:group) }
        let_it_be(:child_group_2) { create(:group, parent: parent_group_2) }
        let_it_be(:nested_project_2) { create(:project, :repository, group: child_group_2) }
        let_it_be(:parent_group_3) { create(:group) }
        let_it_be(:child_group_3) { create(:group, parent: parent_group_3) }
        let_it_be(:premium_group) { create(:group) }
        let_it_be(:basic_project) { create(:project, :repository, group: group) }

        before_all do
          other_group.add_developer(user)
          parent_group_2.add_developer(user)
          parent_group_3.add_developer(user)
          premium_group.add_guest(user)
        end

        context 'when namespace authorization is enforced' do
          context 'when user has no access to the namespace' do
            it 'returns 404 when namespace is provided via root_namespace_id' do
              get api(path, user), headers: workhorse_headers, params: {
                root_namespace_id: unauthorized_group.id
              }

              expect(response).to have_gitlab_http_status(:not_found)
              expect(json_response['message']).to eq('404 Namespace Not Found')
            end

            it 'returns 404 when namespace is provided via namespace_id' do
              get api(path, user), headers: workhorse_headers, params: {
                namespace_id: unauthorized_group.id
              }

              expect(response).to have_gitlab_http_status(:not_found)
              expect(json_response['message']).to eq('404 Namespace Not Found')
            end

            it 'returns 404 when namespace is provided via header' do
              get api(path, user), headers: workhorse_headers.merge(
                'X-Gitlab-Namespace-Id' => unauthorized_group.id
              )

              expect(response).to have_gitlab_http_status(:not_found)
              expect(json_response['message']).to eq('404 Namespace Not Found')
            end
          end

          context 'when user has access to the namespace' do
            it 'succeeds when accessing authorized namespace' do
              get api(path, user), headers: workhorse_headers, params: {
                root_namespace_id: group.id
              }

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
                'x-gitlab-root-namespace-id' => group.id.to_s
              )
            end
          end
        end

        context 'when context validation is required' do
          context 'with project context' do
            context 'when namespace does not match project context' do
              it 'returns 403 forbidden when using mismatched namespace via root_namespace_id' do
                get api(path, user), headers: workhorse_headers, params: {
                  project_id: project.id,
                  root_namespace_id: other_group.id
                }

                expect(response).to have_gitlab_http_status(:forbidden)
                expect(json_response['message']).to eq('403 Forbidden - Namespace does not match project context')
              end

              it 'returns 403 forbidden when using mismatched namespace via header' do
                get api(path, user), headers: workhorse_headers.merge(
                  'X-Gitlab-Namespace-Id' => other_group.id
                ), params: {
                  project_id: project.id
                }

                expect(response).to have_gitlab_http_status(:forbidden)
                expect(json_response['message']).to eq('403 Forbidden - Namespace does not match project context')
              end

              it 'returns 403 forbidden when namespace_id does not match project' do
                get api(path, user), headers: workhorse_headers, params: {
                  project_id: project.id,
                  namespace_id: other_group.id
                }

                expect(response).to have_gitlab_http_status(:forbidden)
                expect(json_response['message']).to eq('403 Forbidden - Namespace does not match project context')
              end
            end

            context 'when namespace matches project context' do
              it 'succeeds when namespace matches project root namespace' do
                get api(path, user), headers: workhorse_headers, params: {
                  project_id: project.id,
                  root_namespace_id: group.id
                }

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
                  'x-gitlab-project-id' => project.id.to_s,
                  'x-gitlab-root-namespace-id' => group.id.to_s
                )
              end
            end

            context 'with nested groups and projects' do
              before do
                allow_any_instance_of(User).to receive(:allowed_to_use).and_return( # rubocop:disable RSpec/AnyInstanceOf -- overriding top-level mock
                  Ai::UserAuthorizable::Response.new(
                    allowed?: true,
                    namespace_ids: [group.id, other_group.id, parent_group_2.id, child_group_2.id]
                  )
                )
              end

              it 'succeeds when using child group namespace with nested project' do
                get api(path, user), headers: workhorse_headers, params: {
                  project_id: nested_project_2.id,
                  namespace_id: child_group_2.id
                }

                expect(response).to have_gitlab_http_status(:ok)
              end

              it 'succeeds when using root namespace with nested project' do
                get api(path, user), headers: workhorse_headers, params: {
                  project_id: nested_project_2.id,
                  root_namespace_id: parent_group_2.id
                }

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
                  'x-gitlab-project-id' => nested_project_2.id.to_s,
                  'x-gitlab-root-namespace-id' => parent_group_2.id.to_s
                )
              end

              it 'returns 403 when using wrong root namespace with nested project' do
                get api(path, user), headers: workhorse_headers, params: {
                  project_id: nested_project_2.id,
                  root_namespace_id: other_group.id
                }

                expect(response).to have_gitlab_http_status(:forbidden)
                expect(json_response['message']).to eq('403 Forbidden - Namespace does not match project context')
              end
            end
          end

          context 'with namespace context (no project)' do
            context 'when namespace does not match workflow context' do
              it 'returns 403 forbidden when root namespace does not match namespace context' do
                get api(path, user), headers: workhorse_headers, params: {
                  namespace_id: group.id,
                  root_namespace_id: other_group.id
                }

                expect(response).to have_gitlab_http_status(:forbidden)
                expect(json_response['message']).to eq('403 Forbidden - Namespace does not match workflow context')
              end
            end

            context 'when namespace matches workflow context' do
              it 'succeeds when namespace matches' do
                get api(path, user), headers: workhorse_headers, params: {
                  namespace_id: group.id,
                  root_namespace_id: group.id
                }

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
                  'x-gitlab-namespace-id' => group.id.to_s,
                  'x-gitlab-root-namespace-id' => group.id.to_s
                )
              end
            end

            context 'with nested groups' do
              before do
                allow_any_instance_of(User).to receive(:allowed_to_use).and_return( # rubocop:disable RSpec/AnyInstanceOf -- overriding top-level mock
                  Ai::UserAuthorizable::Response.new(
                    allowed?: true,
                    namespace_ids: [group.id, other_group.id, parent_group_3.id, child_group_3.id]
                  )
                )
              end

              it 'succeeds when namespace matches child group root ancestor' do
                get api(path, user), headers: workhorse_headers, params: {
                  namespace_id: child_group_3.id,
                  root_namespace_id: parent_group_3.id
                }

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
                  'x-gitlab-namespace-id' => child_group_3.id.to_s,
                  'x-gitlab-root-namespace-id' => parent_group_3.id.to_s
                )
              end

              it 'returns 403 when root namespace does not match child group ancestor' do
                get api(path, user), headers: workhorse_headers, params: {
                  namespace_id: child_group_3.id,
                  root_namespace_id: other_group.id
                }

                expect(response).to have_gitlab_http_status(:forbidden)
                expect(json_response['message']).to eq('403 Forbidden - Namespace does not match workflow context')
              end
            end
          end
        end

        context 'when context validation is NOT required (no project or namespace params)' do
          it 'succeeds with no namespace params at all' do
            get api(path, user), headers: workhorse_headers

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['DuoWorkflow']['Service']['Headers']['x-gitlab-root-namespace-id']).to be_nil
          end
        end

        context 'with security edge cases' do
          context 'when attempting to escalate privileges' do
            it 'blocks attempt to use premium namespace with basic project' do
              get api(path, user), headers: workhorse_headers, params: {
                project_id: basic_project.id,
                root_namespace_id: premium_group.id
              }

              expect(response).to have_gitlab_http_status(:forbidden)
              expect(json_response['message']).to eq('403 Forbidden - Namespace does not match project context')
            end

            it 'blocks attempt to inject namespace via header with project context' do
              get api(path, user), headers: workhorse_headers.merge(
                'X-Gitlab-Namespace-Id' => premium_group.id
              ), params: {
                project_id: basic_project.id
              }

              expect(response).to have_gitlab_http_status(:forbidden)
              expect(json_response['message']).to eq('403 Forbidden - Namespace does not match project context')
            end
          end

          context 'with multiple conflicting namespace sources' do
            it 'validates against the effective namespace when namespace_id conflicts with header' do
              get api(path, user), headers: workhorse_headers.merge(
                'X-Gitlab-Namespace-Id' => group.id
              ), params: {
                project_id: project.id,
                namespace_id: other_group.id
              }

              expect(response).to have_gitlab_http_status(:forbidden)
              expect(json_response['message']).to eq('403 Forbidden - Namespace does not match project context')
            end

            it 'validates root_namespace_id against project context when both root and namespace_id provided' do
              get api(path, user), headers: workhorse_headers, params: {
                project_id: project.id,
                root_namespace_id: other_group.id,
                namespace_id: group.id
              }

              expect(response).to have_gitlab_http_status(:forbidden)
              expect(json_response['message']).to eq('403 Forbidden - Namespace does not match project context')
            end
          end
        end
      end
      # rubocop:enable RSpec/MultipleMemoizedHelpers

      context 'when duo_agent_platform_enable_direct_http is enabled' do
        subject(:get_response) do
          stub_feature_flags(duo_agent_platform_enable_direct_http: true)
          get api(path, user), headers: workhorse_headers
        end

        it 'returns the websocket configuration with proper headers' do
          get_response

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.media_type).to eq(Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE)

          expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
            'x-gitlab-base-url' => Gitlab.config.gitlab.url,
            'x-gitlab-oauth-token' => 'oauth_token',
            'authorization' => 'Bearer token',
            'x-gitlab-authentication-type' => 'oidc',
            'x-gitlab-enabled-feature-flags' => anything,
            'x-gitlab-instance-id' => anything,
            'x-gitlab-version' => Gitlab.version_info.to_s,
            'x-gitlab-unidirectional-streaming' => 'enabled'
          )

          expect(json_response['DuoWorkflow']['Service']['Secure']).to eq(true)
        end

        it_behaves_like 'ServiceURI has the right value', false

        context 'when project_id parameter is provided' do
          it 'includes x-gitlab-project-id header' do
            stub_feature_flags(duo_agent_platform_enable_direct_http: true)

            get api(path, user), headers: workhorse_headers, params: { project_id: project.id }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
              'x-gitlab-project-id' => project.id.to_s
            )
          end

          it 'sets x-gitlab-project-id header to nil when project_id is blank' do
            stub_feature_flags(duo_agent_platform_enable_direct_http: true)

            get api(path, user), headers: workhorse_headers, params: { project_id: '' }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['DuoWorkflow']['Service']['Headers']['x-gitlab-project-id']).to be_nil
          end
        end

        context 'when namespace_id parameter is provided' do
          it 'includes x-gitlab-namespace-id header' do
            stub_feature_flags(duo_agent_platform_enable_direct_http: true)

            get api(path, user), headers: workhorse_headers, params: { namespace_id: group.id }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
              'x-gitlab-namespace-id' => group.id.to_s
            )
          end

          it 'falls back to X-Gitlab-Namespace-Id header when namespace_id is blank' do
            stub_feature_flags(duo_agent_platform_enable_direct_http: true)

            get api(path, user), headers: workhorse_headers.merge('X-Gitlab-Namespace-Id' => group.id),
              params: { namespace_id: '' }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['DuoWorkflow']['Service']['Headers']).to include(
              'x-gitlab-namespace-id' => group.id.to_s,
              'x-gitlab-root-namespace-id' => group.id.to_s
            )
          end
        end
      end

      context 'for self hosted duo agent platform' do
        let_it_be(:self_hosted_model) do
          create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219')
        end

        let_it_be_with_refind(:duo_agent_platform_setting) do
          create(:ai_feature_setting, :duo_agent_platform_agentic_chat, self_hosted_model: self_hosted_model)
        end

        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it 'includes model metadata headers in the response' do
          get_response

          expect(response).to have_gitlab_http_status(:ok)

          headers = json_response['DuoWorkflow']['Service']['Headers']
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

        it 'sets x-gitlab-self-hosted-dap-billing-enabled header to true when billing should occur' do
          allow(Ai::SelfHostedDapBilling).to receive(:should_bill?)
            .with(duo_agent_platform_setting).and_return(true)

          get_response

          expect(response).to have_gitlab_http_status(:ok)

          headers = json_response['DuoWorkflow']['Service']['Headers']
          expect(headers).to include(
            'x-gitlab-self-hosted-dap-billing-enabled' => 'true'
          )
        end

        it 'sets x-gitlab-self-hosted-dap-billing-enabled header to false when billing should not occur' do
          allow(Ai::SelfHostedDapBilling).to receive(:should_bill?)
            .with(duo_agent_platform_setting).and_return(false)

          get_response

          expect(response).to have_gitlab_http_status(:ok)

          headers = json_response['DuoWorkflow']['Service']['Headers']
          expect(headers).to include(
            'x-gitlab-self-hosted-dap-billing-enabled' => 'false'
          )
        end

        it 'creates ModelMetadata with the correct feature setting' do
          expect(::Gitlab::Llm::AiGateway::AgentPlatform::ModelMetadata).to receive(:new)
            .with(feature_setting: duo_agent_platform_setting)
            .and_call_original

          get api(path, user), headers: workhorse_headers
        end

        it_behaves_like 'ServiceURI has the right value', true

        context 'when feature setting is disabled' do
          subject(:get_response) do
            duo_agent_platform_setting.update!(provider: :disabled)

            get api(path, user), headers: workhorse_headers
          end

          it 'does not include model metadata headers when provider is disabled' do
            get_response

            expect(response).to have_gitlab_http_status(:ok)

            headers = json_response['DuoWorkflow']['Service']['Headers']
            expect(headers).to include(
              'x-gitlab-oauth-token' => 'oauth_token',
              'x-gitlab-unidirectional-streaming' => 'enabled'
            )
            expect(headers).not_to have_key('x-gitlab-agent-platform-model-metadata')
          end

          it_behaves_like 'ServiceURI has the right value', false
        end
      end

      context 'for model selection at instance level' do
        let_it_be(:instance_setting) do
          create(:instance_model_selection_feature_setting,
            feature: :duo_agent_platform_agentic_chat,
            offered_model_ref: 'claude-3-7-sonnet-20250219')
        end

        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it 'includes model metadata headers in the response' do
          get_response

          expect(response).to have_gitlab_http_status(:ok)

          headers = json_response['DuoWorkflow']['Service']['Headers']

          metadata = ::Gitlab::Json.parse(headers['x-gitlab-agent-platform-model-metadata'])
          expect(metadata).to include(
            'provider' => 'gitlab',
            'feature_setting' => 'duo_agent_platform_agentic_chat',
            'identifier' => 'claude-3-7-sonnet-20250219'
          )
        end

        it_behaves_like 'ServiceURI has the right value', false
      end

      context 'for model selection at namespace level', :saas do
        include_context 'with model selections fetch definition service side-effect context'

        # CRITICAL FIX: Use a different variable name and add user access
        let_it_be(:model_selection_group) { create(:group) }

        before_all do
          model_selection_group.add_developer(user)
        end

        before do
          stub_saas_features(gitlab_com_subscriptions: true)

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

          headers = json_response['DuoWorkflow']['Service']['Headers']
          expect(headers).to include(
            'x-gitlab-oauth-token' => 'oauth_token',
            'x-gitlab-unidirectional-streaming' => 'enabled'
          )

          expect(headers).not_to have_key('x-gitlab-agent-platform-model-metadata')
        end

        it_behaves_like 'ServiceURI has the right value', false

        context 'when namespace params are provided' do
          context 'when a model selection setting exists' do
            let_it_be(:namespace_setting) do
              create(:ai_namespace_feature_setting,
                namespace: model_selection_group,
                feature: :duo_agent_platform_agentic_chat,
                offered_model_ref: 'claude_sonnet_3_7_20250219')
            end

            context 'when provided as param[:root_namespace_id]' do
              subject(:get_response) do
                get api(path, user), headers: workhorse_headers, params: { root_namespace_id: model_selection_group.id }
              end

              it 'includes model metadata headers' do
                get_response

                expect(response).to have_gitlab_http_status(:ok)

                headers = json_response['DuoWorkflow']['Service']['Headers']
                expect(headers).to have_key('x-gitlab-agent-platform-model-metadata')

                metadata = ::Gitlab::Json.parse(headers['x-gitlab-agent-platform-model-metadata'])
                expect(metadata).to include(
                  'provider' => 'gitlab',
                  'feature_setting' => 'duo_agent_platform_agentic_chat',
                  'identifier' => 'claude_sonnet_3_7_20250219'
                )
              end

              it_behaves_like 'ServiceURI has the right value', false

              context 'when user_selected_model_identifier is provided' do
                context 'when a valid user_selected_model_identifier is provided' do
                  let(:user_selected_model_identifier) { 'claude_sonnet_4_20250514' }

                  subject(:get_response) do
                    get api(path, user), headers: workhorse_headers, params: {
                      root_namespace_id: model_selection_group.id,
                      user_selected_model_identifier: user_selected_model_identifier
                    }
                  end

                  it 'continues to use the namespace-level model selection' do
                    get_response

                    expect(response).to have_gitlab_http_status(:ok)

                    headers = json_response['DuoWorkflow']['Service']['Headers']
                    metadata = ::Gitlab::Json.parse(headers['x-gitlab-agent-platform-model-metadata'])
                    expect(metadata).to include(
                      'provider' => 'gitlab',
                      'feature_setting' => 'duo_agent_platform_agentic_chat',
                      'identifier' => 'claude_sonnet_3_7_20250219'
                    )
                  end

                  it_behaves_like 'ServiceURI has the right value', false
                end
              end
            end

            context 'when provided as header[X-Gitlab-Namespace-Id]' do
              subject(:get_response) do
                get api(path, user),
                  headers: workhorse_headers.merge('X-Gitlab-Namespace-Id' => model_selection_group.id)
              end

              it 'includes model metadata headers' do
                get_response

                expect(response).to have_gitlab_http_status(:ok)

                headers = json_response['DuoWorkflow']['Service']['Headers']
                metadata = ::Gitlab::Json.parse(headers['x-gitlab-agent-platform-model-metadata'])
                expect(metadata).to include(
                  'provider' => 'gitlab',
                  'feature_setting' => 'duo_agent_platform_agentic_chat',
                  'identifier' => 'claude_sonnet_3_7_20250219'
                )
              end

              it_behaves_like 'ServiceURI has the right value', false
            end
          end

          context 'when a model selection setting does not exist' do
            context 'when provided as param[:root_namespace_id]' do
              subject(:get_response) do
                get api(path, user), headers: workhorse_headers, params: { root_namespace_id: model_selection_group.id }
              end

              it 'includes model metadata headers with default model' do
                get_response

                expect(response).to have_gitlab_http_status(:ok)

                headers = json_response['DuoWorkflow']['Service']['Headers']

                metadata = ::Gitlab::Json.parse(headers['x-gitlab-agent-platform-model-metadata'])
                expect(metadata).to include(
                  'provider' => 'gitlab',
                  'feature_setting' => 'duo_agent_platform_agentic_chat',
                  'identifier' => nil
                )
              end

              it_behaves_like 'ServiceURI has the right value', false
            end

            context 'when a user_selected_model_identifier is provided' do
              subject(:get_response) do
                get api(path, user), headers: workhorse_headers, params: {
                  root_namespace_id: model_selection_group.id,
                  user_selected_model_identifier: user_selected_model_identifier
                }
              end

              context 'when a valid user_selected_model_identifier is provided' do
                let(:user_selected_model_identifier) { 'claude_sonnet_4_20250514' }

                it 'uses the user-selected model' do
                  get_response

                  expect(response).to have_gitlab_http_status(:ok)

                  headers = json_response['DuoWorkflow']['Service']['Headers']
                  metadata = ::Gitlab::Json.parse(headers['x-gitlab-agent-platform-model-metadata'])
                  expect(metadata).to include(
                    'provider' => 'gitlab',
                    'feature_setting' => 'duo_agent_platform_agentic_chat',
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

                  headers = json_response['DuoWorkflow']['Service']['Headers']
                  metadata = ::Gitlab::Json.parse(headers['x-gitlab-agent-platform-model-metadata'])
                  expect(metadata).to include(
                    'provider' => 'gitlab',
                    'feature_setting' => 'duo_agent_platform_agentic_chat',
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

                  headers = json_response['DuoWorkflow']['Service']['Headers']
                  metadata = ::Gitlab::Json.parse(headers['x-gitlab-agent-platform-model-metadata'])
                  expect(metadata).to include(
                    'provider' => 'gitlab',
                    'feature_setting' => 'duo_agent_platform_agentic_chat',
                    'identifier' => nil
                  )
                end

                it_behaves_like 'ServiceURI has the right value', false
              end
            end
          end
        end
      end

      context 'for X-Gitlab-Agent-Platform-Feature-Setting-Name header', :saas do
        context 'when X-Gitlab-Agent-Platform-Feature-Setting-Name header is provided', :request_store do
          let(:custom_feature_name) { 'any_dap_feature' }

          before do
            ::Gitlab::Auth::Identity.link_from_scoped_user(service_account, user)
          end

          it 'uses the header value as feature_name when calling DuoAgentPlatformModelMetadataService' do
            expect(::Ai::DuoWorkflows::DuoAgentPlatformModelMetadataService).to receive(:new).with(
              hash_including(feature_name: custom_feature_name.to_sym)
            ).and_call_original

            get api(path, user),
              headers: workhorse_headers.merge('X-Gitlab-Agent-Platform-Feature-Setting-Name' => custom_feature_name)
          end

          it 'uses the header value when calling FeatureSettingSelectionService' do
            expect(::Ai::FeatureSettingSelectionService).to receive(:new).with(
              user,
              custom_feature_name.to_sym,
              anything
            ).and_call_original

            get api(path, user), headers: workhorse_headers.merge(
              'X-Gitlab-Agent-Platform-Feature-Setting-Name' => custom_feature_name
            ), params: { root_namespace_id: group.id }
          end

          it 'uses a composite identity token' do
            expect_next_instance_of(::Ai::DuoWorkflows::WorkflowContextGenerationService) do |service|
              expect(service).to receive(:generate_oauth_token_with_composite_identity_support)
                .and_call_original

              expect(service).not_to receive(:generate_oauth_token)
            end

            get api(path, user), headers: workhorse_headers.merge(
              'X-Gitlab-Agent-Platform-Feature-Setting-Name' => custom_feature_name
            ), params: { root_namespace_id: group.id }
          end
        end

        context 'when X-Gitlab-Agent-Platform-Feature-Setting-Name header is missing' do
          let(:custom_feature_name) { 'duo_agent_platform' }

          it 'uses a regular non-composite identity token' do
            expect_next_instance_of(::Ai::DuoWorkflows::WorkflowContextGenerationService) do |service|
              expect(service).to receive(:generate_oauth_token)
                .and_call_original

              expect(service).not_to receive(:generate_oauth_token_with_composite_identity_support)
            end

            get api(path, user), headers: workhorse_headers.merge(
              'X-Gitlab-Agent-Platform-Feature-Setting-Name' => nil
            ), params: { root_namespace_id: group.id }
          end
        end

        context 'when X-Gitlab-Agent-Platform-Feature-Setting-Name header is not provided' do
          it 'defaults to agentic_chat_feature_name when calling DuoAgentPlatformModelMetadataService' do
            expect(::Ai::DuoWorkflows::DuoAgentPlatformModelMetadataService).to receive(:new).with(
              hash_including(feature_name: ::Ai::ModelSelection::FeaturesConfigurable.agentic_chat_feature_name)
            ).and_call_original

            get api(path, user), headers: workhorse_headers, params: { root_namespace_id: group.id }
          end

          it 'defaults to agentic_chat_feature_name when calling FeatureSettingSelectionService' do
            expect(::Ai::FeatureSettingSelectionService).to receive(:new).with(
              user,
              ::Ai::ModelSelection::FeaturesConfigurable.agentic_chat_feature_name,
              anything
            ).and_call_original

            get api(path, user), headers: workhorse_headers, params: { root_namespace_id: group.id }
          end

          it 'uses a regular non-composite identity token' do
            expect_next_instance_of(::Ai::DuoWorkflows::WorkflowContextGenerationService) do |service|
              expect(service).to receive(:generate_oauth_token)
                .and_call_original

              expect(service).not_to receive(:generate_oauth_token_with_composite_identity_support)
            end

            get api(path, user), headers: workhorse_headers, params: { root_namespace_id: group.id }
          end
        end
      end

      context 'for x-gitlab-model-prompt-cache-enabled at instance-level' do
        it 'returns false in x-gitlab-model-prompt-cache-enabled header' do
          get api(path, user), headers: workhorse_headers

          expect(
            json_response['DuoWorkflow']['Service']['Headers']['x-gitlab-model-prompt-cache-enabled']
          ).to eq('false')
        end
      end

      context 'for x-gitlab-model-prompt-cache-enabled at group-level' do
        it 'returns true in x-gitlab-model-prompt-cache-enabled header' do
          group.namespace_settings.update_column(:model_prompt_cache_enabled, true)

          get api(path, user), headers: workhorse_headers, params: { namespace_id: group.id }

          expect(
            json_response['DuoWorkflow']['Service']['Headers']['x-gitlab-model-prompt-cache-enabled']
          ).to eq('true')
        end

        it 'returns false in x-gitlab-model-prompt-cache-enabled header' do
          group.namespace_settings.update_column(:model_prompt_cache_enabled, false)

          get api(path, user), headers: workhorse_headers, params: { namespace_id: group.id }

          expect(
            json_response['DuoWorkflow']['Service']['Headers']['x-gitlab-model-prompt-cache-enabled']
          ).to eq('false')
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
      it 'is allowed' do
        get api(path, oauth_access_token: ai_workflows_oauth_token), headers: workhorse_headers

        expect(response).to have_gitlab_http_status(:ok)
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
      expect(privilege4['default_enabled']).to eq(true)
    end
  end
end
