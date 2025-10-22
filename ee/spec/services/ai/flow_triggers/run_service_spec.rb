# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FlowTriggers::RunService, feature_category: :duo_agent_platform do
  let_it_be_with_refind(:project) { create(:project, :repository) }
  let_it_be_with_reload(:service_account) { create(:service_account, maintainer_of: project) }

  let_it_be(:current_user) { create(:user, maintainer_of: project) }
  let_it_be(:resource) { create(:issue, project: project) }
  let_it_be(:existing_note) { create(:note, project: project, noteable: resource) }

  let(:params) { { input: 'test input', event: :mention, discussion: existing_note.discussion } }

  let_it_be(:flow_trigger) do
    create(:ai_flow_trigger, project: project, user: service_account, config_path: '.gitlab/duo/flow.yml')
  end

  let(:flow_definition) do
    {
      'image' => 'ruby:3.0',
      'commands' => ['echo "Hello World"', 'ruby script.rb'],
      'variables' => %w[API_KEY DATABASE_URL],
      'injectGatewayToken' => true
    }.to_yaml
  end

  let_it_be(:project_variable1) do
    create(:ci_variable, project: project, key: 'DATABASE_URL', value: 'postgres://test')
  end

  let_it_be(:project_variable2) { create(:ci_variable, project: project, key: 'API_KEY', value: 'secret123') }
  let_it_be(:project_variable3) do
    create(:ci_variable, project: project, key: 'ANOTHER_VAR_THAT_SHOULD_NOT_BE_PASSED', value: 'really secret')
  end

  let(:mock_token_response) do
    ServiceResponse.success(payload: {
      token: 'test-token-123',
      headers: {
        'Authorization' => 'Bearer test-token-123',
        'Content-Type' => 'application/json'
      }
    })
  end

  subject(:service) do
    described_class.new(
      project: project,
      current_user: current_user,
      resource: resource,
      flow_trigger: flow_trigger
    )
  end

  before do
    # Enable necessary feature flags and settings
    stub_feature_flags(duo_workflow: true, duo_workflow_in_ci: true)

    # Enable duo features on project
    project.project_setting.update!(
      duo_features_enabled: true,
      duo_remote_flows_enabled: true
    )

    # Setup LLM stage check
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
    allow(::Ability).to receive(:allowed?).and_return(true)
    allow(current_user).to receive(:allowed_to_use?).and_return(true)

    # Setup chat authorizer
    authorizer_double = instance_double(::Gitlab::Llm::Utils::Authorizer::Response)
    allow(::Gitlab::Llm::Chain::Utils::ChatAuthorizer)
      .to receive(:resource)
      .and_return(authorizer_double)
    allow(authorizer_double).to receive(:allowed?).and_return(true)
  end

  describe '#initialize' do
    context 'when composite identity can be used' do
      let_it_be(:oauth_app) { create(:oauth_application, name: 'Duo Workflow', scopes: %w[api read_user]) }

      before do
        service_account.update!(composite_identity_enforced: true)
        ::Ai::Setting.instance.update!(
          duo_workflow_service_account_user: service_account,
          duo_workflow_oauth_application: oauth_app
        )
        stub_feature_flags(ai_flow_triggers_use_composite_identity: true)
      end

      it 'calls link_composite_identity!' do
        identity_double = instance_double(::Gitlab::Auth::Identity)
        allow(::Gitlab::Auth::Identity).to receive(:fabricate).with(service_account).and_return(identity_double)
        allow(identity_double).to receive(:composite?).and_return(true)
        expect(identity_double).to receive(:link!).with(current_user)

        service
      end

      context 'when identity is not composite' do
        it 'does not call link! on identity' do
          identity_double = instance_double(::Gitlab::Auth::Identity)
          allow(::Gitlab::Auth::Identity).to receive(:fabricate).with(service_account).and_return(identity_double)
          allow(identity_double).to receive(:composite?).and_return(false)
          expect(identity_double).not_to receive(:link!)
          service
        end
      end

      context 'when identity is nil' do
        it 'does not raise an error' do
          allow(::Gitlab::Auth::Identity).to receive(:fabricate).with(service_account).and_return(nil)

          expect { service }.not_to raise_error
        end
      end
    end

    context 'when composite identity cannot be used' do
      it 'does not call link_composite_identity!' do
        expect(::Gitlab::Auth::Identity).not_to receive(:fabricate)

        service
      end

      context 'when current_user is nil' do
        let(:current_user) { nil }

        it 'does not call fabricate on Gitlab::Auth::Identity' do
          expect(::Gitlab::Auth::Identity).not_to receive(:fabricate)

          service
        end
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(ai_flow_triggers_use_composite_identity: false)
        end

        it 'does not call fabricate on Gitlab::Auth::Identity' do
          expect(::Gitlab::Auth::Identity).not_to receive(:fabricate)

          service
        end
      end

      context 'when oauth application is not configured' do
        before do
          ::Ai::Setting.instance.update!(duo_workflow_oauth_application: nil)
        end

        it 'does not call fabricate on Gitlab::Auth::Identity' do
          expect(::Gitlab::Auth::Identity).not_to receive(:fabricate)

          service
        end
      end

      context 'when service account does not have composite identity enforced' do
        before do
          service_account.update!(composite_identity_enforced: false)
        end

        it 'does not call fabricate on Gitlab::Auth::Identity' do
          expect(::Gitlab::Auth::Identity).not_to receive(:fabricate)

          service
        end
      end
    end
  end

  describe '#execute' do
    before do
      # Mock the flow definition fetching instead of creating/updating files
      allow(project.repository).to receive(:blob_data_at).and_return(flow_definition)

      token_service_double = instance_double(::Ai::ThirdPartyAgents::TokenService)
      allow(::Ai::ThirdPartyAgents::TokenService).to receive(:new)
        .with(current_user: current_user)
        .and_return(token_service_double)
      allow(token_service_double).to receive(:direct_access_token).and_return(mock_token_response)
    end

    it 'creates duo workflow with correct parameters' do
      expect { service.execute(params) }.to change { ::Ai::DuoWorkflows::Workflow.count }.by(1)

      workflow = ::Ai::DuoWorkflows::Workflow.last
      expect(workflow.workflow_definition).to eq("Trigger - #{flow_trigger.description}")
      expect(workflow.goal).to eq('test input')
      expect(workflow.environment).to eq('web')
      expect(workflow.project).to eq(project)
      expect(workflow.user).to eq(current_user)
    end

    it 'creates workflow_workload association' do
      expect { service.execute(params) }.to change { ::Ai::DuoWorkflows::WorkflowsWorkload.count }.by(1)

      workflow = ::Ai::DuoWorkflows::Workflow.last
      workload = ::Ci::Workloads::Workload.last

      association = ::Ai::DuoWorkflows::WorkflowsWorkload.last
      expect(association.workflow).to eq(workflow)
      expect(association.project_id).to eq(project.id)
      expect(association.workload_id).to eq(workload.id)
    end

    it 'executes the workload service and creates a workload' do
      expect { service.execute(params) }.to change { ::Ci::Workloads::Workload.count }.by(1)

      response = service.execute(params)
      expect(response).to be_success

      workload = response.payload
      expect(workload).to be_persisted
      expect(workload.variable_inclusions.map(&:variable_name)).to eq(%w[API_KEY DATABASE_URL])
    end

    context 'when injectGatewayToken is true' do
      it 'builds workload definition with gateway token variables' do
        expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
          workload_definition = kwargs[:workload_definition]
          expect(workload_definition.image).to eq('ruby:3.0')
          expect(workload_definition.commands).to eq(['echo "Hello World"', 'ruby script.rb'])
          variables = workload_definition.variables

          expect(variables[:AI_FLOW_CONTEXT]).to match(/id..#{resource.id}/)
          expect(variables[:AI_FLOW_INPUT]).to eq('test input')
          expect(variables[:AI_FLOW_EVENT]).to eq('mention')
          expect(variables[:AI_FLOW_DISCUSSION_ID]).to eq(existing_note.discussion_id)

          expect(variables[:AI_FLOW_AI_GATEWAY_TOKEN]).to eq('test-token-123')
          expect(variables[:AI_FLOW_AI_GATEWAY_HEADERS]).to eq(
            "Authorization: Bearer test-token-123\nContent-Type: application/json")

          expect(kwargs[:ci_variables_included]).to eq(%w[API_KEY DATABASE_URL])
          expect(kwargs[:source]).to eq(:duo_workflow)

          original_method.call(**kwargs)
        end

        response = service.execute(params)
        expect(response).to be_success
      end

      it 'calls token service to get direct access token' do
        token_service_double = instance_double(::Ai::ThirdPartyAgents::TokenService)
        expect(::Ai::ThirdPartyAgents::TokenService).to receive(:new)
          .with(current_user: current_user)
          .and_return(token_service_double)
        expect(token_service_double).to receive(:direct_access_token).and_return(mock_token_response)

        response = service.execute(params)
        expect(response).to be_success
      end

      context 'when token service returns error' do
        let(:error_token_response) do
          ServiceResponse.error(message: 'Token generation failed')
        end

        before do
          token_service_double = instance_double(::Ai::ThirdPartyAgents::TokenService)
          allow(::Ai::ThirdPartyAgents::TokenService).to receive(:new)
            .with(current_user: current_user)
            .and_return(token_service_double)
          allow(token_service_double).to receive(:direct_access_token).and_return(error_token_response)
        end

        it 'returns error without creating workload' do
          expect { service.execute(params) }.to change { ::Ai::DuoWorkflows::Workflow.count }.by(1)
          expect { service.execute(params) }.not_to change { ::Ci::Workloads::Workload.count }

          response = service.execute(params)
          expect(response).to be_error
          expect(response.message).to eq('Token generation failed')
        end
      end

      context 'when a flow is triggered by a service account' do
        let_it_be(:current_user) { create(:service_account, maintainer_of: project) }

        it 'returns an error' do
          response = service.execute(params)
          expect(response).to be_error
          expect(response.message).to eq('cannot be triggered by non-human users')
        end
      end

      context 'when token response has empty headers' do
        let(:mock_token_response_empty_headers) do
          ServiceResponse.success(payload: {
            token: 'test-token-123',
            headers: {}
          })
        end

        before do
          token_service_double = instance_double(::Ai::ThirdPartyAgents::TokenService)
          allow(::Ai::ThirdPartyAgents::TokenService).to receive(:new)
            .with(current_user: current_user)
            .and_return(token_service_double)
          allow(token_service_double).to receive(:direct_access_token).and_return(mock_token_response_empty_headers)
        end

        it 'builds variables with empty headers string' do
          expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
            variables = kwargs[:workload_definition].variables
            expect(variables[:AI_FLOW_AI_GATEWAY_TOKEN]).to eq('test-token-123')
            expect(variables[:AI_FLOW_AI_GATEWAY_HEADERS]).to eq('')
            original_method.call(**kwargs)
          end

          response = service.execute(params)
          expect(response).to be_success
        end
      end

      context 'when token response has nil headers' do
        let(:mock_token_response_nil_headers) do
          ServiceResponse.success(payload: {
            token: 'test-token-123',
            headers: nil
          })
        end

        before do
          token_service_double = instance_double(::Ai::ThirdPartyAgents::TokenService)
          allow(::Ai::ThirdPartyAgents::TokenService).to receive(:new)
                                                           .with(current_user: current_user)
                                                           .and_return(token_service_double)
          allow(token_service_double).to receive(:direct_access_token).and_return(mock_token_response_nil_headers)
        end

        it 'builds variables with empty headers string' do
          expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
            variables = kwargs[:workload_definition].variables
            expect(variables[:AI_FLOW_AI_GATEWAY_TOKEN]).to eq('test-token-123')
            expect(variables[:AI_FLOW_AI_GATEWAY_HEADERS]).to eq('')
            original_method.call(**kwargs)
          end

          response = service.execute(params)
          expect(response).to be_success
        end
      end
    end

    context 'when injectGatewayToken is false' do
      let(:flow_definition) do
        {
          'image' => 'ruby:3.0',
          'commands' => ['echo "Hello World"', 'ruby script.rb'],
          'variables' => %w[API_KEY DATABASE_URL],
          'injectGatewayToken' => false
        }.to_yaml
      end

      before do
        allow(::Ai::ThirdPartyAgents::TokenService).to receive(:new).and_call_original
      end

      it 'does not call token service' do
        expect(::Ai::ThirdPartyAgents::TokenService).not_to receive(:new)

        response = service.execute(params)
        expect(response).to be_success
      end

      it 'builds workload definition without gateway token variables' do
        expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
          workload_definition = kwargs[:workload_definition]
          variables = workload_definition.variables

          expect(variables[:AI_FLOW_CONTEXT]).to match(/id..#{resource.id}/)
          expect(variables[:AI_FLOW_INPUT]).to eq('test input')
          expect(variables[:AI_FLOW_EVENT]).to eq('mention')
          expect(variables[:AI_FLOW_DISCUSSION_ID]).to eq(existing_note.discussion_id)

          # These should not be present
          expect(variables).not_to have_key(:AI_FLOW_AI_GATEWAY_TOKEN)
          expect(variables).not_to have_key(:AI_FLOW_AI_GATEWAY_HEADERS)

          original_method.call(**kwargs)
        end

        response = service.execute(params)
        expect(response).to be_success
      end
    end

    context 'when injectGatewayToken is not present' do
      let(:flow_definition) do
        {
          'image' => 'ruby:3.0',
          'commands' => ['echo "Hello World"', 'ruby script.rb'],
          'variables' => %w[API_KEY DATABASE_URL]
          # injectGatewayToken is not present
        }.to_yaml
      end

      before do
        allow(::Ai::ThirdPartyAgents::TokenService).to receive(:new).and_call_original
      end

      it 'does not call token service' do
        expect(::Ai::ThirdPartyAgents::TokenService).not_to receive(:new)

        response = service.execute(params)
        expect(response).to be_success
      end

      it 'builds workload definition without gateway token variables' do
        expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
          workload_definition = kwargs[:workload_definition]
          variables = workload_definition.variables

          expect(variables[:AI_FLOW_CONTEXT]).to match(/id..#{resource.id}/)
          expect(variables[:AI_FLOW_INPUT]).to eq('test input')
          expect(variables[:AI_FLOW_EVENT]).to eq('mention')
          expect(variables[:AI_FLOW_DISCUSSION_ID]).to eq(existing_note.discussion_id)

          # These should not be present
          expect(variables).not_to have_key(:AI_FLOW_AI_GATEWAY_TOKEN)
          expect(variables).not_to have_key(:AI_FLOW_AI_GATEWAY_HEADERS)

          original_method.call(**kwargs)
        end

        response = service.execute(params)
        expect(response).to be_success
      end
    end

    context 'when duo_workflow_oauth_application is set in Ai::Setting' do
      let_it_be(:oauth_app) { create(:oauth_application, name: 'Duo Workflow', scopes: %w[api read_user]) }

      before do
        ::Ai::Setting.instance.update!(
          duo_workflow_service_account_user: service_account, duo_workflow_oauth_application: oauth_app
        )
      end

      context 'when composite identity is not enforced for trigger user' do
        it 'does not create variable AI_FLOW_GITLAB_TOKEN' do
          expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
            workload_definition = kwargs[:workload_definition]
            variables = workload_definition.variables

            expect(variables[:AI_FLOW_CONTEXT]).to match(/id..#{resource.id}/)
            expect(variables[:AI_FLOW_INPUT]).to eq('test input')
            expect(variables[:AI_FLOW_EVENT]).to eq('mention')
            expect(variables[:AI_FLOW_DISCUSSION_ID]).to eq(existing_note.discussion_id)
            expect(variables[:AI_FLOW_GITLAB_TOKEN]).to be_nil

            original_method.call(**kwargs)
          end

          initial_oauth_access_tokens_count = OauthAccessToken.count

          response = service.execute(params)

          expect(response).to be_success
          expect(OauthAccessToken.count).to eq initial_oauth_access_tokens_count
        end
      end

      context 'when composite identity is enforced for service account' do
        before do
          service_account.update!(composite_identity_enforced: true)
        end

        context 'when FF ai_flow_triggers_use_composite_identity is disabled' do
          before do
            stub_feature_flags(ai_flow_triggers_use_composite_identity: false)
          end

          it 'does not create variable AI_FLOW_GITLAB_TOKEN' do
            expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
              workload_definition = kwargs[:workload_definition]
              variables = workload_definition.variables

              expect(variables[:AI_FLOW_CONTEXT]).to match(/id..#{resource.id}/)
              expect(variables[:AI_FLOW_INPUT]).to eq('test input')
              expect(variables[:AI_FLOW_EVENT]).to eq('mention')
              expect(variables[:AI_FLOW_DISCUSSION_ID]).to eq(existing_note.discussion_id)
              expect(variables[:AI_FLOW_GITLAB_TOKEN]).to be_nil

              original_method.call(**kwargs)
            end

            initial_oauth_access_tokens_count = OauthAccessToken.count

            response = service.execute(params)

            expect(response).to be_success
            expect(OauthAccessToken.count).to eq initial_oauth_access_tokens_count
          end
        end

        it 'creates variable AI_FLOW_GITLAB_TOKEN along with other AI flow variables' do
          expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
            workload_definition = kwargs[:workload_definition]
            variables = workload_definition.variables

            expect(variables[:AI_FLOW_CONTEXT]).to match(/id..#{resource.id}/)
            expect(variables[:AI_FLOW_INPUT]).to eq('test input')
            expect(variables[:AI_FLOW_EVENT]).to eq('mention')
            expect(variables[:AI_FLOW_DISCUSSION_ID]).to eq(existing_note.discussion_id)
            expect(variables[:AI_FLOW_GITLAB_TOKEN]).to be_present

            original_method.call(**kwargs)
          end

          initial_oauth_access_tokens_count = OauthAccessToken.count

          response = service.execute(params)

          expect(response).to be_success
          expect(OauthAccessToken.count).to eq initial_oauth_access_tokens_count + 1
          oauth_access_token = OauthAccessToken.last
          expect(oauth_access_token.resource_owner).to eq(service_account)
          expect(oauth_access_token.application).to eq(oauth_app)
          duration = Ai::DuoWorkflows::CreateCompositeOauthAccessTokenService::TOKEN_EXPIRES_IN
          expect(oauth_access_token.expires_in).to eq(duration)
          expect(oauth_access_token.scopes).to contain_exactly('api', "user:#{current_user.id}")
          expect(oauth_access_token.organization).to eq(project.organization)
        end
      end
    end

    it 'creates appropriate notes' do
      expect(Note.count).to eq(1)
      expect(::Ci::Workloads::Workload.count).to eq(0)

      response = service.execute(params)

      expect(response).to be_success
      expect(::Ci::Workloads::Workload.count).to eq(1)
      expect(Note.count).to eq(2)

      expect(Note.last.note).to include('✅ Agent has started. You can view the progress')

      workflow = ::Ai::DuoWorkflows::Workflow.last
      expect(Note.last.note).to match(/automate.agent.sessions.#{workflow.id}/)
    end

    it 'updates workflow status to running initially and then to start on success' do
      response = service.execute(params)
      expect(response).to be_success

      workflow = ::Ai::DuoWorkflows::Workflow.last
      expect(workflow.status_name).to eq(:running)
    end

    context 'when workload execution fails' do
      before do
        allow_next_instance_of(::Ci::Workloads::RunWorkloadService) do |instance|
          error = ServiceResponse.error(
            message: 'Workload failed', payload: instance_double(::Ci::Workloads::Workload, id: 999)
          )

          allow(instance).to receive(:execute).and_return(error)
        end
      end

      it 'still creates workflow and handles the failure' do
        expect { service.execute(params) }.to change { ::Ai::DuoWorkflows::Workflow.count }.by(1)

        # The service should still attempt to update workflow status even on failure
        workflow = ::Ai::DuoWorkflows::Workflow.last
        expect(workflow).to be_present
      end
    end

    context 'when workflow creation fails' do
      before do
        allow_next_instance_of(::Ai::DuoWorkflows::CreateWorkflowService) do |instance|
          error_response = ServiceResponse.error(message: 'Workflow creation failed')
          allow(error_response).to receive(:error?).and_return(true)
          allow(instance).to receive(:execute).and_return(error_response)
        end
      end

      it 'returns error response without creating workload' do
        expect { service.execute(params) }.not_to change { ::Ci::Workloads::Workload.count }

        response = service.execute(params)
        expect(response).to be_error
        expect(response.message).to eq('Workflow creation failed')
      end
    end

    context 'when resource is a MergeRequest' do
      let_it_be(:merge_request) do
        create(:merge_request,
          source_project: project,
          target_project: project,
          source_branch: 'feature-branch',
          target_branch: 'another-branch'
        )
      end

      let_it_be(:resource) { merge_request }

      it 'includes source branch in branch args' do
        expect(Ci::Workloads::RunWorkloadService).to receive(:new).with(
          project: project,
          current_user: service_account,
          source: :duo_workflow,
          workload_definition: an_instance_of(Ci::Workloads::WorkloadDefinition),
          ci_variables_included: %w[API_KEY DATABASE_URL],
          create_branch: true,
          source_branch: 'feature-branch'
        ).and_call_original

        service.execute(params)
      end
    end

    context 'when resource is not a MergeRequest' do
      it 'does not include source branch in branch args' do
        expect(Ci::Workloads::RunWorkloadService).to receive(:new).with(
          project: project,
          current_user: service_account,
          source: :duo_workflow,
          workload_definition: an_instance_of(Ci::Workloads::WorkloadDefinition),
          ci_variables_included: %w[API_KEY DATABASE_URL],
          create_branch: true
        ).and_call_original

        service.execute(params)
      end
    end

    context 'when flow definition file does not exist' do
      before do
        allow(service).to receive(:fetch_flow_definition).and_return(nil)
      end

      it 'returns error without calling workload service' do
        response = service.execute(params)
        expect(response).to be_error
        expect(response.message).to eq('invalid or missing flow definition')
      end
    end

    context 'when flow definition is not valid' do
      before do
        allow(service).to receive(:fetch_flow_definition).and_return(nil)
      end

      it 'returns error without calling workload service' do
        expect(Ci::Workloads::RunWorkloadService).not_to receive(:new)

        response = service.execute(params)

        expect(response).to be_error
        expect(response.message).to eq('invalid or missing flow definition')
      end
    end

    context 'when flow trigger has ai_catalog_item_consumer' do
      let(:ai_catalog_item) { create(:ai_catalog_flow) }
      let(:ai_catalog_item_consumer) do
        create(:ai_catalog_item_consumer,
          item: ai_catalog_item, project: project, pinned_version_prefix: nil)
      end

      let(:flow_trigger_with_catalog) do
        create(:ai_flow_trigger,
          project: project,
          user: service_account,
          config_path: nil,
          ai_catalog_item_consumer: ai_catalog_item_consumer)
      end

      let(:catalog_workflow) { create(:duo_workflows_workflow, project: project, user: current_user) }
      let(:catalog_execute_response) do
        ServiceResponse.success(payload: { workflow: catalog_workflow })
      end

      subject(:service) do
        described_class.new(
          project: project,
          current_user: current_user,
          resource: resource,
          flow_trigger: flow_trigger_with_catalog
        )
      end

      before do
        allow_next_instance_of(::Ai::Catalog::Flows::ExecuteService) do |instance|
          allow(instance).to receive(:execute).and_return(catalog_execute_response)
        end
      end

      it 'calls Ai::Catalog::Flows::ExecuteService with correct parameters' do
        expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
          project: project,
          current_user: current_user,
          params: {
            flow: ai_catalog_item,
            flow_version: ai_catalog_item.latest_version,
            event_type: 'mention',
            user_prompt: start_with("Input: test input\nContext:"),
            execute_workflow: true
          }
        ).and_call_original

        service.execute(params)
      end

      context 'when ai_catalog_third_party_flows feature flag is disabled' do
        before do
          stub_feature_flags(ai_catalog_third_party_flows: false)
        end

        it 'calls Ai::Catalog::Flows::ExecuteService' do
          expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new)

          service.execute(params)
        end
      end

      it 'creates a new workflow' do
        expect { service.execute(params) }.to change { ::Ai::DuoWorkflows::Workflow.count }

        response = service.execute(params)

        expect(response).to be_success
      end

      it 'does not create workload or workload association' do
        expect { service.execute(params) }.not_to change { ::Ci::Workloads::Workload.count }
        expect { service.execute(params) }.not_to change { ::Ai::DuoWorkflows::WorkflowsWorkload.count }
      end

      it 'creates appropriate notes with catalog workflow' do
        expect(::Ai::DuoWorkflows::UpdateWorkflowStatusService).not_to receive(:new)
        expect(Note.count).to eq(1)

        response = service.execute(params)

        expect(response).to be_success
        expect(Note.count).to eq(2)

        expect(Note.last.note).to include('✅ Agent has started. You can view the progress')
        expect(Note.last.note).to match(/automate.agent.sessions.#{catalog_workflow.id}/)
      end

      context 'when catalog execute service fails' do
        let(:catalog_execute_error_response) do
          ServiceResponse.error(message: 'Catalog execution failed')
        end

        before do
          allow_next_instance_of(::Ai::Catalog::Flows::ExecuteService) do |instance|
            allow(instance).to receive(:execute).and_return(catalog_execute_error_response)
          end
        end

        it 'returns error response' do
          expect(::Ai::DuoWorkflows::UpdateWorkflowStatusService).not_to receive(:new)

          response = service.execute(params)
          expect(response).to be_error
          expect(response.message).to eq('Catalog execution failed')
        end
      end

      context 'when flow trigger has ai_catalog_item with third_party_flow_type' do
        let(:ai_catalog_item) { create(:ai_catalog_third_party_flow, latest_version:) }
        let(:latest_version) do
          create(:ai_catalog_item_version, :for_third_party_flow, definition: third_party_flow_definition)
        end

        let(:third_party_flow_definition) do
          {
            'image' => 'node:18',
            'commands' => ['npm install', 'node index.js'],
            'variables' => ['API_TOKEN'],
            'injectGatewayToken' => true
          }
        end

        context 'when ai_catalog_third_party_flows feature flag is disabled' do
          before do
            stub_feature_flags(ai_catalog_third_party_flows: false)
          end

          it 'returns an error response' do
            expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)

            response = service.execute(params)
            expect(response).to be_error
            expect(response.message).to eq('ai_catalog_third_party_flows feature flag is not enabled')
          end
        end

        it 'creates workload with third party flow definition' do
          expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
            workload_definition = kwargs[:workload_definition]
            expect(workload_definition.image).to eq('node:18')
            expect(workload_definition.commands).to eq(['npm install', 'node index.js'])
            expect(kwargs[:ci_variables_included]).to eq(['API_TOKEN'])

            original_method.call(**kwargs)
          end

          response = service.execute(params)
          expect(response).to be_success
        end
      end
    end

    context 'when flow definition is not a valid' do
      where(:flow_definition) do
        ['invalid yaml', '[not_a_hash]', "--- &1\n- *1\n", "%x", ""]
      end

      with_them do
        it 'returns nil without calling workload service' do
          expect(Ci::Workloads::RunWorkloadService).not_to receive(:new)

          response = service.execute(params)
          expect(response).to be_error
          expect(response.message).to eq('invalid or missing flow definition')
        end
      end
    end
  end
end
