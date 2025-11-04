# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::StartWorkflowService, feature_category: :duo_agent_platform do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:developer) { create(:user, developer_of: project) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }
  let_it_be(:reporter) { create(:user, reporter_of: project) }

  let(:image) { 'example.com/example-image:latest' }
  let(:workflow) { create(:duo_workflows_workflow, user: maintainer, image: image, **container_params) }
  let(:container_params) { { project: project } }
  let(:duo_agent_platform_feature_setting) { nil }

  let(:params) do
    {
      goal: 'test-goal',
      workflow: workflow,
      workflow_oauth_token: 'test-oauth-token',
      workflow_service_token: 'test-service-token',
      workflow_metadata: { key: 'val' }.to_json,
      duo_agent_platform_feature_setting: duo_agent_platform_feature_setting
    }
  end

  shared_examples "success" do
    it 'creates a workload to execute workflow with the correct definition' do
      shadowed_project = project
      expect(Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |method, **kwargs|
        project = kwargs[:project]
        expect(project).to eq(shadowed_project)
        method.call(**kwargs)
      end

      expect(execute).to be_success

      workload_id = execute.payload[:workload_id]
      expect(workload_id).not_to be_nil
      expect(workflow.workflows_workloads.first).to have_attributes(project_id: project.id, workload_id: workload_id)

      workload = Ci::Workloads::Workload.find_by_id([workload_id])
      expect(workload.branch_name).to start_with('workloads/')
      expect(workload.branch_name).to start_with('workloads/')
    end
  end

  shared_examples 'failure' do
    it 'does not create a workload to execute workflow' do
      expect(execute).to be_error
      expect(execute.reason).to eq(:feature_unavailable)
      expect(execute.message).to eq('Can not execute workflow in CI')
    end
  end

  shared_examples 'successful flow config' do
    let(:flow_config) do
      { 'version' => 'experimental', 'environment' => 'remote' }
    end

    let(:schema_version) { 'experimental' }

    context 'when flow_config is provided' do
      let(:params) do
        super().merge(
          flow_config: flow_config,
          flow_config_schema_version: schema_version
        )
      end

      it 'sets DUO_WORKFLOW_FLOW_CONFIG as JSON string and DUO_WORKFLOW_FLOW_CONFIG_SCHEMA_VERSION' do
        expect(Ci::Workloads::RunWorkloadService)
          .to receive(:new).and_wrap_original do |method, **kwargs|
          workload_definition = kwargs[:workload_definition]
          variables = workload_definition.variables

          expect(variables[:DUO_WORKFLOW_FLOW_CONFIG]).to eq(::Gitlab::Json.dump(flow_config))
          expect(variables[:DUO_WORKFLOW_FLOW_CONFIG_SCHEMA_VERSION]).to eq(schema_version)
          method.call(**kwargs)
        end

        expect(execute).to be_success
      end
    end

    context 'when flow_config is not provided' do
      it 'sets DUO_WORKFLOW_FLOW_CONFIG as empty string and DUO_WORKFLOW_FLOW_CONFIG_SCHEMA_VERSION as nil' do
        expect(Ci::Workloads::RunWorkloadService)
          .to receive(:new).and_wrap_original do |method, **kwargs|
          workload_definition = kwargs[:workload_definition]
          variables = workload_definition.variables

          expect(variables[:DUO_WORKFLOW_FLOW_CONFIG]).to be_nil
          expect(variables[:DUO_WORKFLOW_FLOW_CONFIG_SCHEMA_VERSION]).to be_nil
          method.call(**kwargs)
        end

        expect(execute).to be_success
      end
    end

    context 'when flow_config is not in Hash format' do
      let(:params) do
        super().merge(
          flow_config: "flow_config",
          flow_config_schema_version: schema_version
        )
      end

      it 'sets DUO_WORKFLOW_FLOW_CONFIG as nil' do
        expect(Ci::Workloads::RunWorkloadService)
          .to receive(:new).and_wrap_original do |method, **kwargs|
          workload_definition = kwargs[:workload_definition]
          variables = workload_definition.variables

          expect(variables[:DUO_WORKFLOW_FLOW_CONFIG]).to be_nil

          method.call(**kwargs)
        end

        expect(execute).to be_success
      end
    end
  end

  shared_examples 'additional context' do
    let(:additional_context) do
      [
        {
          Category: "agent_user_environment",
          Content: "some content",
          Metadata: "{}"
        }
      ]
    end

    def standard_context_content(parsed_context)
      context = parsed_context.find { |ctx| ctx["Category"] == "agent_platform_standard_context" }
      ::Gitlab::Json.parse(context["Content"]) if context
    end

    context 'when additional_context is provided' do
      let(:params) { super().merge(additional_context: additional_context) }

      it 'includes the original context' do
        expect(Ci::Workloads::RunWorkloadService)
          .to receive(:new).and_wrap_original do |method, **kwargs|
          workload_definition = kwargs[:workload_definition]
          variables = workload_definition.variables
          parsed_context = ::Gitlab::Json.parse(variables[:DUO_WORKFLOW_ADDITIONAL_CONTEXT_CONTENT])

          expect(parsed_context).to include(hash_including("Category" => "agent_user_environment"))
          method.call(**kwargs)
        end

        expect(execute).to be_success
      end

      it 'adds agent_platform_standard_context' do
        expect(Ci::Workloads::RunWorkloadService)
          .to receive(:new).and_wrap_original do |method, **kwargs|
          workload_definition = kwargs[:workload_definition]
          variables = workload_definition.variables
          parsed_context = ::Gitlab::Json.parse(variables[:DUO_WORKFLOW_ADDITIONAL_CONTEXT_CONTENT])
          standard_context = parsed_context.find { |ctx| ctx["Category"] == "agent_platform_standard_context" }

          expect(standard_context).to be_present
          method.call(**kwargs)
        end

        expect(execute).to be_success
      end
    end

    context 'when agent_platform_standard_context already exists' do
      let(:additional_context) do
        [
          {
            Category: "agent_user_environment",
            Content: "some content",
            Metadata: "{}"
          },
          {
            Category: "agent_platform_standard_context",
            Content: ::Gitlab::Json.dump({ "key" => "value" })
          }
        ]
      end

      let(:params) { super().merge(additional_context: additional_context) }

      it 'does not create a duplicate' do
        expect(Ci::Workloads::RunWorkloadService)
          .to receive(:new).and_wrap_original do |method, **kwargs|
          workload_definition = kwargs[:workload_definition]
          variables = workload_definition.variables
          parsed_context = ::Gitlab::Json.parse(variables[:DUO_WORKFLOW_ADDITIONAL_CONTEXT_CONTENT])
          standard_contexts = parsed_context.select { |ctx| ctx["Category"] == "agent_platform_standard_context" }

          expect(standard_contexts.size).to eq(1)
          method.call(**kwargs)
        end

        expect(execute).to be_success
      end

      it 'overrides the existing context' do
        expect(Ci::Workloads::RunWorkloadService)
          .to receive(:new).and_wrap_original do |method, **kwargs|
          workload_definition = kwargs[:workload_definition]
          variables = workload_definition.variables
          parsed_context = ::Gitlab::Json.parse(variables[:DUO_WORKFLOW_ADDITIONAL_CONTEXT_CONTENT])
          content = standard_context_content(parsed_context)

          expect(content).not_to eq({ "key" => "value" })
          expect(content.keys).to match_array(%w[workload_branch primary_branch session_owner_id])
          method.call(**kwargs)
        end

        expect(execute).to be_success
      end
    end

    context 'when source_branch exists' do
      let(:params) { super().merge(additional_context: additional_context, source_branch: 'feature-branch') }

      before do
        project.repository.create_branch('feature-branch', project.default_branch)
      end

      it 'uses source_branch as primary_branch' do
        expect(Ci::Workloads::RunWorkloadService)
          .to receive(:new).and_wrap_original do |method, **kwargs|
          workload_definition = kwargs[:workload_definition]
          variables = workload_definition.variables
          parsed_context = ::Gitlab::Json.parse(variables[:DUO_WORKFLOW_ADDITIONAL_CONTEXT_CONTENT])
          content = standard_context_content(parsed_context)

          expect(content["primary_branch"]).to eq('feature-branch')
          method.call(**kwargs)
        end

        expect(execute).to be_success
      end
    end

    context 'when source_branch does not exist' do
      let(:params) { super().merge(additional_context: additional_context, source_branch: 'non-existent-branch') }

      it 'falls back to default branch as primary_branch' do
        expect(Ci::Workloads::RunWorkloadService)
          .to receive(:new).and_wrap_original do |method, **kwargs|
          workload_definition = kwargs[:workload_definition]
          variables = workload_definition.variables
          parsed_context = ::Gitlab::Json.parse(variables[:DUO_WORKFLOW_ADDITIONAL_CONTEXT_CONTENT])
          content = standard_context_content(parsed_context)

          expect(content["primary_branch"]).to eq(project.default_branch_or_main)
          method.call(**kwargs)
        end

        expect(execute).to be_success
      end
    end

    context 'when additional_context is not provided' do
      it 'only includes agent_platform_standard_context' do
        expect(Ci::Workloads::RunWorkloadService)
          .to receive(:new).and_wrap_original do |method, **kwargs|
          workload_definition = kwargs[:workload_definition]
          variables = workload_definition.variables
          parsed_context = ::Gitlab::Json.parse(variables[:DUO_WORKFLOW_ADDITIONAL_CONTEXT_CONTENT])

          expect(parsed_context.size).to eq(1)
          expect(parsed_context.first["Category"]).to eq("agent_platform_standard_context")
          method.call(**kwargs)
        end

        expect(execute).to be_success
      end
    end
  end

  shared_context 'with Duo enabled' do
    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      allow(maintainer).to receive(:allowed_to_use?).and_return(true)
    end
  end

  subject(:execute) { described_class.new(workflow: workflow, params: params).execute }

  context 'with workflow enablement checks' do
    using RSpec::Parameterized::TableSyntax
    where(:duo_workflow_ff, :duo_workflow_in_ci_ff, :duo_features_enabled, :duo_remote_flows_enabled, :current_user,
      :shared_examples) do
      false | false | true  | true  | ref(:maintainer) | 'failure'
      true  | false | true  | true  | ref(:developer)  | 'failure'
      false | true  | true  | true  | ref(:developer)  | 'failure'
      true  | true  | true  | false | ref(:maintainer) | 'failure'
      true  | true  | true  | true  | ref(:maintainer) | 'success'
      true  | true  | true  | true  | ref(:reporter)   | 'failure'
      true  | true  | false | true  | ref(:developer)  | 'failure'
      true  | true  | false | false | ref(:developer)  | 'failure'
      true  | true  | true  | true  | ref(:maintainer) | 'successful flow config'
      true  | true  | true  | true  | ref(:developer) | 'additional context'
    end

    with_them do
      before do
        stub_feature_flags(duo_workflow: duo_workflow_ff, duo_workflow_in_ci: duo_workflow_in_ci_ff)
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
        allow(current_user).to receive(:allowed_to_use?).and_return(true)
        project.project_setting.update!(duo_features_enabled: duo_features_enabled,
          duo_remote_flows_enabled: duo_remote_flows_enabled)
        workflow.update!(user: current_user)
      end

      include_examples params[:shared_examples]
    end
  end

  context 'when workflow is not project-level' do
    let(:container_params) { { namespace: group } }

    it 'returns an error' do
      expect(execute).to be_error
      expect(execute.reason).to eq(:unprocessable_entity)
      expect(execute.message).to eq('Only project-level workflow is supported')
    end
  end

  context 'when ci pipeline could not be created' do
    let(:pipeline) do
      instance_double(Ci::Pipeline, created_successfully?: false, full_error_messages: 'full error messages')
    end

    let(:service_response) { ServiceResponse.error(message: 'Error in creating pipeline', payload: pipeline) }

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      # rubocop:disable RSpec/AnyInstanceOf -- not the next instance
      allow_any_instance_of(User).to receive(:allowed_to_use?).and_return(true)
      # rubocop:enable RSpec/AnyInstanceOf
      allow_next_instance_of(Ci::CreatePipelineService) do |instance|
        allow(instance).to receive(:execute).and_return(service_response)
      end
      project.project_setting.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)
    end

    it 'does not start a pipeline to execute workflow' do
      expect(execute).to be_error
      expect(execute.reason).to eq(:workload_failure)
      expect(execute.message).to eq('Error in creating workload: full error messages')
    end
  end

  context 'when use_service_account param is set' do
    let_it_be(:service_account) { create(:user, :service_account, composite_identity_enforced: true) }

    before do
      params[:use_service_account] = true
      settings_double = instance_double(::Ai::Setting,
        duo_workflow_service_account_user: service_account,
        duo_agent_platform_service_url: 'http://agent-platform-url:50052',
        ai_gateway_url: nil
      )
      allow(::Ai::Setting).to receive(:instance).and_return(settings_double)
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      # rubocop:disable RSpec/AnyInstanceOf -- not the next instance
      allow_any_instance_of(User).to receive(:allowed_to_use?).and_return(true)
      # rubocop:enable RSpec/AnyInstanceOf
      project.project_setting.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)

      mock_workload = instance_double(Ci::Workloads::Workload, id: 123)

      allow_next_instance_of(Ci::Workloads::WorkloadBranchService,
        hash_including(current_user: service_account)
      ) do |service|
        allow(service).to receive(:execute).and_return(
          ServiceResponse.success(payload: { branch_name: 'workloads/123' })
        )
      end
      allow_next_instance_of(Ci::Workloads::RunWorkloadService,
        hash_including(current_user: service_account)
      ) do |service|
        allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: mock_workload))
      end
    end

    it 'creates developer authorization for service account' do
      execute
      expect(project.member(service_account).access_level).to eq(Gitlab::Access::DEVELOPER)
    end

    it 'calls workload service with the service account' do
      expect(execute).to be_success
    end
  end

  context 'with source_branch parameter' do
    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      # rubocop:disable RSpec/AnyInstanceOf -- not the next instance
      allow_any_instance_of(User).to receive(:allowed_to_use?).and_return(true)
      # rubocop:enable RSpec/AnyInstanceOf
      project.project_setting.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)
    end

    it 'creates workload branch from source_branch and passes ref to RunWorkloadService when provided' do
      local_params = params.merge(source_branch: 'feature-branch')
      service = described_class.new(workflow: workflow, params: local_params)

      expect(::Ci::Workloads::WorkloadBranchService).to receive(:new).with(
        hash_including(source_branch: 'feature-branch')
      ).and_call_original

      expect(service.execute).to be_success
    end

    it 'passes nil when source_branch not provided' do
      expect(::Ci::Workloads::WorkloadBranchService).to receive(:new).with(
        hash_including(source_branch: nil)
      ).and_call_original

      expect(execute).to be_success
    end
  end

  context 'with custom image configuration' do
    let(:custom_image) { 'registry.gitlab.com/custom/image:v1.0' }
    let(:duo_config) { instance_double(::Gitlab::DuoAgentPlatform::Config) }

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      allow(maintainer).to receive(:allowed_to_use?).and_return(true)
      project.project_setting.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)
      allow(::Gitlab::DuoAgentPlatform::Config).to receive(:new).with(project).and_return(duo_config)
    end

    context 'when .gitlab/duo/agent-config.yml exists with valid configuration' do
      before do
        allow(duo_config).to receive_messages(
          valid?: true,
          default_image: custom_image,
          setup_script: nil,
          cache_config: nil
        )
      end

      context 'when workflow has no image specified' do
        let(:image) { nil }

        it 'uses the configured image from .gitlab/duo/agent-config.yml' do
          expect(Ci::Workloads::RunWorkloadService)
            .to receive(:new).and_wrap_original do |method, **kwargs|
            workload_definition = kwargs[:workload_definition]
            expect(workload_definition.image).to eq(custom_image)
            method.call(**kwargs)
          end

          expect(execute).to be_success
        end
      end

      context 'when workflow already has an image specified' do
        let(:image) { 'workflow-specific-image:latest' }

        it 'prefers the workflow image over the configured image' do
          expect(Ci::Workloads::RunWorkloadService)
            .to receive(:new).and_wrap_original do |method, **kwargs|
            workload_definition = kwargs[:workload_definition]
            expect(workload_definition.image).to eq(image)
            method.call(**kwargs)
          end

          expect(execute).to be_success
        end
      end
    end

    context 'when .gitlab/duo/agent-config.yml exists but has no default_image' do
      before do
        allow(duo_config).to receive_messages(
          valid?: true,
          default_image: nil,
          setup_script: nil,
          cache_config: nil
        )
      end

      let(:image) { nil }

      it 'falls back to the default IMAGE constant' do
        expect(Ci::Workloads::RunWorkloadService)
          .to receive(:new).and_wrap_original do |method, **kwargs|
          workload_definition = kwargs[:workload_definition]
          expect(workload_definition.image).to eq(described_class::IMAGE)
          method.call(**kwargs)
        end

        expect(execute).to be_success
      end
    end
  end

  context 'with image priority' do
    let(:workflow_image) { 'workflow-image:latest' }
    let(:config_image) { 'config-image:latest' }
    let(:duo_config) { instance_double(::Gitlab::DuoAgentPlatform::Config) }

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      allow(maintainer).to receive(:allowed_to_use?).and_return(true)
      project.project_setting.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)
      allow(::Gitlab::DuoAgentPlatform::Config).to receive(:new).with(project).and_return(duo_config)
      allow(duo_config).to receive_messages(
        valid?: true,
        default_image: config_image,
        setup_script: nil,
        cache_config: nil
      )
    end

    context 'when workflow image is present' do
      let(:image) { workflow_image }

      it 'uses the workflow image' do
        expect(Ci::Workloads::RunWorkloadService)
          .to receive(:new).and_wrap_original do |method, **kwargs|
          workload_definition = kwargs[:workload_definition]
          expect(workload_definition.image).to eq(workflow_image)
          method.call(**kwargs)
        end

        expect(execute).to be_success
      end
    end

    context 'when only config image is present' do
      let(:image) { nil }

      it 'uses the config image' do
        expect(Ci::Workloads::RunWorkloadService)
          .to receive(:new).and_wrap_original do |method, **kwargs|
          workload_definition = kwargs[:workload_definition]
          expect(workload_definition.image).to eq(config_image)
          method.call(**kwargs)
        end

        expect(execute).to be_success
      end
    end

    context 'when neither workflow nor config image are present' do
      let(:image) { nil }

      before do
        allow(duo_config).to receive_messages(
          default_image: nil,
          setup_script: nil,
          cache_config: nil
        )
      end

      it 'uses the default IMAGE constant' do
        expect(Ci::Workloads::RunWorkloadService)
          .to receive(:new).and_wrap_original do |method, **kwargs|
          workload_definition = kwargs[:workload_definition]
          expect(workload_definition.image).to eq(described_class::IMAGE)
          method.call(**kwargs)
        end

        expect(execute).to be_success
      end
    end
  end

  shared_examples 'sets AGENT_PLATFORM_MODEL_METADATA' do
    it 'sets the correct model metadata' do
      expect(Ci::Workloads::RunWorkloadService)
        .to receive(:new).and_wrap_original do |method, **kwargs|
        variables = kwargs[:workload_definition].variables
        expect(variables[:AGENT_PLATFORM_MODEL_METADATA]).to eq(expected_model_metadata)
        method.call(**kwargs)
      end

      expect(execute).to be_success
    end
  end

  context 'for AGENT_PLATFORM_MODEL_METADATA' do
    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      allow(maintainer).to receive(:allowed_to_use?).and_return(true)
      project.project_setting.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)
    end

    context 'when self-hosted feature setting exists' do
      let(:expected_model_metadata) do
        {
          provider: 'openai',
          name: 'claude_3',
          endpoint: 'http://localhost:11434/v1',
          api_key: 'token',
          identifier: 'claude-3-7-sonnet-20250219'
        }.to_json
      end

      let_it_be(:model) do
        create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219')
      end

      let_it_be(:duo_agent_platform_feature_setting) do
        create(:ai_feature_setting, :duo_agent_platform, self_hosted_model: model)
      end

      it_behaves_like 'sets AGENT_PLATFORM_MODEL_METADATA'
    end

    context 'when instance level model selection exists' do
      let(:expected_model_metadata) do
        {
          provider: 'gitlab',
          feature_setting: 'duo_agent_platform',
          identifier: 'claude-3-7-sonnet-20250219'
        }.to_json
      end

      let_it_be(:duo_agent_platform_feature_setting) do
        create(:instance_model_selection_feature_setting, feature: :duo_agent_platform)
      end

      it_behaves_like 'sets AGENT_PLATFORM_MODEL_METADATA'
    end

    context 'when namespace level model selection exists', :saas do
      let(:expected_model_metadata) do
        {
          provider: 'gitlab',
          feature_setting: 'duo_agent_platform',
          identifier: 'claude_sonnet_3_7_20250219'
        }.to_json
      end

      let_it_be(:duo_agent_platform_feature_setting) do
        create(:ai_namespace_feature_setting,
          namespace: project.namespace,
          feature: :duo_agent_platform,
          offered_model_ref: "claude_sonnet_3_7_20250219")
      end

      it_behaves_like 'sets AGENT_PLATFORM_MODEL_METADATA'
    end

    context 'when no feature setting exists' do
      let(:expected_model_metadata) { nil }

      it_behaves_like 'sets AGENT_PLATFORM_MODEL_METADATA'
    end
  end

  shared_examples 'sets DUO_WORKFLOW_SERVICE_SERVER' do
    it 'sets the correct service server URL' do
      expect(Ci::Workloads::RunWorkloadService)
        .to receive(:new).and_wrap_original do |method, **kwargs|
        variables = kwargs[:workload_definition].variables
        expect(variables[:DUO_WORKFLOW_SERVICE_SERVER]).to eq(expected_service_server_url)
        method.call(**kwargs)
      end

      expect(execute).to be_success
    end
  end

  context 'for DUO_WORKFLOW_SERVICE_SERVER' do
    let(:cloud_connector_url) { 'cloud.staging.gitlab.com:443' }
    let(:self_hosted_url) { 'self-hosted-dap-service-url:50052' }

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      allow(maintainer).to receive(:allowed_to_use?).and_return(true)
      project.project_setting.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)
      allow(Gitlab::DuoWorkflow::Client).to receive_messages(self_hosted_url: self_hosted_url,
        cloud_connected_url: cloud_connector_url)
    end

    context 'when self-hosted feature setting exists' do
      let(:expected_service_server_url) { self_hosted_url }

      let_it_be(:model) do
        create(:ai_self_hosted_model, model: :claude_3, identifier: 'claude-3-7-sonnet-20250219')
      end

      let_it_be(:duo_agent_platform_feature_setting) do
        create(:ai_feature_setting, :duo_agent_platform, self_hosted_model: model)
      end

      it_behaves_like 'sets DUO_WORKFLOW_SERVICE_SERVER'
    end

    context 'when instance level model selection exists' do
      let(:expected_service_server_url) { cloud_connector_url }

      let_it_be(:duo_agent_platform_feature_setting) do
        create(:instance_model_selection_feature_setting, feature: :duo_agent_platform)
      end

      it_behaves_like 'sets DUO_WORKFLOW_SERVICE_SERVER'
    end

    context 'when namespace level model selection exists', :saas do
      let(:expected_service_server_url) { cloud_connector_url }

      let_it_be(:duo_agent_platform_feature_setting) do
        create(:ai_namespace_feature_setting,
          namespace: project.namespace,
          feature: :duo_agent_platform,
          offered_model_ref: "claude_sonnet_3_7_20250219")
      end

      it_behaves_like 'sets DUO_WORKFLOW_SERVICE_SERVER'
    end

    context 'when no feature setting exists' do
      let(:expected_service_server_url) { cloud_connector_url }

      it_behaves_like 'sets DUO_WORKFLOW_SERVICE_SERVER'
    end
  end

  context 'with setup_script configuration' do
    let(:duo_config) { instance_double(::Gitlab::DuoAgentPlatform::Config) }
    let(:setup_commands) { ['npm install', 'npm run build', 'npm test'] }

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      allow(maintainer).to receive(:allowed_to_use?).and_return(true)
      project.project_setting.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)
      allow(::Gitlab::DuoAgentPlatform::Config).to receive(:new).with(project).and_return(duo_config)
      allow(duo_config).to receive_messages(
        valid?: true,
        default_image: nil,
        cache_config: nil
      )
    end

    context 'when setup_script is present' do
      before do
        allow(duo_config).to receive(:setup_script).and_return(setup_commands)
      end

      it 'prepends setup_script commands to the main commands' do
        expect(Ci::Workloads::RunWorkloadService).to receive(:new) do |workload_definition:, **_kwargs|
          commands = workload_definition.commands

          # Verify setup commands are prepended
          expect(commands[0]).to eq('npm install')
          expect(commands[1]).to eq('npm run build')
          expect(commands[2]).to eq('npm test')

          # Verify main commands follow
          expect(commands[3]).to eq('echo $DUO_WORKFLOW_DEFINITION')
          expect(commands[4]).to eq('echo $DUO_WORKFLOW_GOAL')
          expect(commands[5]).to eq('git checkout $CI_WORKLOAD_REF')

          # Total should be setup commands + main commands
          expect(commands.size).to eq(11) # 3 setup + 8 main
        end.and_call_original

        expect(execute).to be_success
      end
    end

    context 'when setup_script is not present' do
      before do
        allow(duo_config).to receive(:setup_script).and_return(nil)
      end

      it 'uses only the main commands' do
        expect(Ci::Workloads::RunWorkloadService).to receive(:new) do |workload_definition:, **_kwargs|
          commands = workload_definition.commands

          # Should start with main commands
          expect(commands[0]).to eq('echo $DUO_WORKFLOW_DEFINITION')
          expect(commands[1]).to eq('echo $DUO_WORKFLOW_GOAL')

          # Should have only main commands
          expect(commands.size).to eq(8)
        end.and_call_original

        expect(execute).to be_success
      end
    end

    context 'when setup_script is empty array' do
      before do
        allow(duo_config).to receive(:setup_script).and_return([])
      end

      it 'does not prepend any commands' do
        expect(Ci::Workloads::RunWorkloadService).to receive(:new) do |workload_definition:, **_kwargs|
          commands = workload_definition.commands

          # Should start with main commands
          expect(commands.first).to eq('echo $DUO_WORKFLOW_DEFINITION')
          expect(commands.size).to eq(8)
        end.and_call_original

        expect(execute).to be_success
      end
    end

    context 'when setup_script has a single command' do
      before do
        allow(duo_config).to receive(:setup_script).and_return(['bundle install'])
      end

      it 'prepends the single command' do
        expect(Ci::Workloads::RunWorkloadService).to receive(:new) do |workload_definition:, **_kwargs|
          commands = workload_definition.commands

          expect(commands[0]).to eq('bundle install')
          expect(commands[1]).to eq('echo $DUO_WORKFLOW_DEFINITION')
          expect(commands.size).to eq(9) # 1 setup + 8 main
        end.and_call_original

        expect(execute).to be_success
      end
    end
  end

  context 'with cache configuration' do
    let(:duo_config) { instance_double(::Gitlab::DuoAgentPlatform::Config) }

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      allow(maintainer).to receive(:allowed_to_use?).and_return(true)
      project.project_setting.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)
      allow(::Gitlab::DuoAgentPlatform::Config).to receive(:new).with(project).and_return(duo_config)
      allow(duo_config).to receive_messages(
        valid?: true,
        default_image: nil,
        setup_script: nil
      )
    end

    context 'when cache config with file-based key is present' do
      let(:cache_config) do
        {
          'key' => { 'files' => ['package.json', 'package-lock.json'] },
          'paths' => ['node_modules', '.npm']
        }
      end

      before do
        allow(duo_config).to receive(:cache_config).and_return(cache_config)
      end

      it 'passes cache configuration to workload definition' do
        expect(Ci::Workloads::RunWorkloadService).to receive(:new) do |workload_definition:, **_kwargs|
          expect(workload_definition.cache).to eq(cache_config)
        end.and_call_original

        expect(execute).to be_success
      end
    end

    context 'when cache config with string key is present' do
      let(:cache_config) do
        {
          'key' => 'my-cache-key',
          'paths' => ['vendor/bundle']
        }
      end

      before do
        allow(duo_config).to receive(:cache_config).and_return(cache_config)
      end

      it 'passes cache configuration to workload definition' do
        expect(Ci::Workloads::RunWorkloadService).to receive(:new) do |workload_definition:, **_kwargs|
          expect(workload_definition.cache).to eq(cache_config)
        end.and_call_original

        expect(execute).to be_success
      end
    end

    context 'when cache config with file key and prefix is present' do
      let(:cache_config) do
        {
          'key' => {
            'files' => ['Gemfile.lock'],
            'prefix' => 'rspec'
          },
          'paths' => ['vendor/ruby']
        }
      end

      before do
        allow(duo_config).to receive(:cache_config).and_return(cache_config)
      end

      it 'passes cache configuration with prefix to workload definition' do
        expect(Ci::Workloads::RunWorkloadService).to receive(:new) do |workload_definition:, **_kwargs|
          expect(workload_definition.cache).to eq(cache_config)
        end.and_call_original

        expect(execute).to be_success
      end
    end

    context 'when cache config with only paths (no key) is present' do
      let(:cache_config) do
        {
          'paths' => ['node_modules']
        }
      end

      before do
        allow(duo_config).to receive(:cache_config).and_return(cache_config)
      end

      it 'passes cache configuration without key to workload definition' do
        expect(Ci::Workloads::RunWorkloadService).to receive(:new) do |workload_definition:, **_kwargs|
          expect(workload_definition.cache).to eq(cache_config)
        end.and_call_original

        expect(execute).to be_success
      end
    end

    context 'when cache config is not present' do
      before do
        allow(duo_config).to receive(:cache_config).and_return(nil)
      end

      it 'does not set cache on workload definition' do
        expect(Ci::Workloads::RunWorkloadService).to receive(:new) do |workload_definition:, **_kwargs|
          # Cache should not be set when config returns nil
          expect(workload_definition.cache).to be_nil
        end.and_call_original

        expect(execute).to be_success
      end
    end
  end

  context 'with both setup_script and cache configuration' do
    let(:duo_config) { instance_double(::Gitlab::DuoAgentPlatform::Config) }
    let(:setup_commands) { ['npm ci', 'npm test'] }
    let(:cache_config) do
      {
        'key' => {
          'files' => ['package.json'],
          'prefix' => 'test'
        },
        'paths' => ['node_modules']
      }
    end

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      allow(maintainer).to receive(:allowed_to_use?).and_return(true)
      project.project_setting.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)
      allow(::Gitlab::DuoAgentPlatform::Config).to receive(:new).with(project).and_return(duo_config)
      allow(duo_config).to receive_messages(
        valid?: true,
        default_image: 'node:18',
        setup_script: setup_commands,
        cache_config: cache_config
      )
    end

    it 'includes both setup commands and cache configuration' do
      expect(Ci::Workloads::RunWorkloadService).to receive(:new) do |workload_definition:, **_kwargs|
        # Check setup commands are prepended
        commands = workload_definition.commands
        expect(commands[0]).to eq('npm ci')
        expect(commands[1]).to eq('npm test')
        expect(commands[2]).to eq('echo $DUO_WORKFLOW_DEFINITION')

        # Check cache is configured
        expect(workload_definition.cache).to eq(cache_config)

        # Check image is set
        expect(workload_definition.image).to eq('node:18')
      end.and_call_original

      expect(execute).to be_success
    end
  end

  context 'without agent configuration' do
    let(:duo_config) { instance_double(::Gitlab::DuoAgentPlatform::Config) }

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      allow(maintainer).to receive(:allowed_to_use?).and_return(true)
      project.project_setting.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)
      allow(::Gitlab::DuoAgentPlatform::Config).to receive(:new).with(project).and_return(duo_config)
      allow(duo_config).to receive_messages(
        valid?: false,
        default_image: nil,
        setup_script: nil,
        cache_config: nil
      )
    end

    it 'uses defaults and does not set cache or setup commands' do
      expect(Ci::Workloads::RunWorkloadService).to receive(:new) do |workload_definition:, **_kwargs|
        # Should use default or workflow image
        expect(workload_definition.image).to eq(image)

        # Should not have setup commands prepended
        commands = workload_definition.commands
        expect(commands.first).to eq('echo $DUO_WORKFLOW_DEFINITION')
        expect(commands.size).to eq(8)

        # Should not have cache
        expect(workload_definition.cache).to be_nil
      end.and_call_original

      expect(execute).to be_success
    end
  end

  context 'with priority ordering for all features' do
    let(:duo_config) { instance_double(::Gitlab::DuoAgentPlatform::Config) }
    let(:workflow_image) { 'workflow-priority:latest' }
    let(:config_image) { 'config-priority:latest' }

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      allow(maintainer).to receive(:allowed_to_use?).and_return(true)
      project.project_setting.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)
      allow(::Gitlab::DuoAgentPlatform::Config).to receive(:new).with(project).and_return(duo_config)
    end

    context 'when workflow has image and config has all features' do
      let(:image) { workflow_image }

      before do
        allow(duo_config).to receive_messages(
          valid?: true,
          default_image: config_image,
          setup_script: ['echo "from config"'],
          cache_config: { 'paths' => ['test'] }
        )
      end

      it 'uses workflow image but config setup_script and cache' do
        expect(Ci::Workloads::RunWorkloadService).to receive(:new) do |workload_definition:, **_kwargs|
          # Workflow image takes priority
          expect(workload_definition.image).to eq(workflow_image)

          # But setup_script from config is used
          expect(workload_definition.commands.first).to eq('echo "from config"')

          # And cache from config is used
          expect(workload_definition.cache).to eq({ 'paths' => ['test'] })
        end.and_call_original

        expect(execute).to be_success
      end
    end
  end

  describe 'DUO_WORKFLOW_GIT_USER_EMAIL variable' do
    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      project.project_setting.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)
      allow(maintainer).to receive(:allowed_to_use?).and_return(true)
      workflow.update!(user: maintainer)
    end

    context 'when workload user has commit_email' do
      before do
        allow(maintainer).to receive_messages(
          commit_email: 'commit@example.com'
        )
      end

      it 'uses the commit_email in environment variables' do
        expect(Ci::Workloads::RunWorkloadService)
          .to receive(:new).and_wrap_original do |method, **kwargs|
          workload_definition = kwargs[:workload_definition]
          variables = workload_definition.variables

          expect(variables[:DUO_WORKFLOW_GIT_USER_EMAIL]).to eq('commit@example.com')
          method.call(**kwargs)
        end

        expect(execute).to be_success
      end
    end

    context 'when workload user has no commit_email' do
      before do
        allow(maintainer).to receive_messages(
          commit_email: nil,
          email: "email@example.com"
        )
      end

      it 'uses the email in environment variables' do
        expect(Ci::Workloads::RunWorkloadService)
          .to receive(:new).and_wrap_original do |method, **kwargs|
          workload_definition = kwargs[:workload_definition]
          variables = workload_definition.variables

          expect(variables[:DUO_WORKFLOW_GIT_USER_EMAIL]).to eq('email@example.com')
          method.call(**kwargs)
        end

        expect(execute).to be_success
      end
    end

    context 'when workload user does not respond to commit_email_or_default' do
      before do
        allow(maintainer).to receive(:respond_to?).and_call_original
        allow(maintainer).to receive(:respond_to?).with(:commit_email_or_default).and_return(false)
      end

      it 'sets DUO_WORKFLOW_GIT_USER_EMAIL to empty string' do
        expect(Ci::Workloads::RunWorkloadService)
          .to receive(:new).and_wrap_original do |method, **kwargs|
          workload_definition = kwargs[:workload_definition]
          variables = workload_definition.variables

          expect(variables[:DUO_WORKFLOW_GIT_USER_EMAIL]).to eq("")
          method.call(**kwargs)
        end

        expect(execute).to be_success
      end
    end
  end

  context 'when shallow_clone is empty', :aggregate_failures do
    include_context 'with Duo enabled'

    it 'sets GIT_DEPTH to 1' do
      expect(Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |method, **kwargs|
        workload_definition = kwargs[:workload_definition]
        variables = workload_definition.variables

        expect(variables[:GIT_DEPTH]).to eq(1)

        method.call(**kwargs)
      end

      expect(execute).to be_success
    end
  end

  context 'when shallow_clone is true', :aggregate_failures do
    include_context 'with Duo enabled'

    let(:params) do
      super().merge(shallow_clone: true)
    end

    it 'sets GIT_DEPTH to 1' do
      expect(Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |method, **kwargs|
        workload_definition = kwargs[:workload_definition]
        variables = workload_definition.variables

        expect(variables[:GIT_DEPTH]).to eq(1)

        method.call(**kwargs)
      end

      expect(execute).to be_success
    end
  end

  context 'when shallow_clone is false', :aggregate_failures do
    include_context 'with Duo enabled'

    let(:params) do
      super().merge(shallow_clone: false)
    end

    it 'does not set GIT_DEPTH' do
      expect(Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |method, **kwargs|
        workload_definition = kwargs[:workload_definition]
        variables = workload_definition.variables

        expect(variables).not_to have_key(:GIT_DEPTH)

        method.call(**kwargs)
      end

      expect(execute).to be_success
    end
  end
end
