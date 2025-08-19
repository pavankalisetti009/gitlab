# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::StartWorkflowService, feature_category: :duo_workflow do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:developer) { create(:user, developer_of: project) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }
  let_it_be(:reporter) { create(:user, reporter_of: project) }

  let(:image) { 'example.com/example-image:latest' }
  let(:workflow) { create(:duo_workflows_workflow, user: maintainer, image: image, **container_params) }
  let(:container_params) { { project: project } }

  let(:params) do
    {
      goal: 'test-goal',
      workflow: workflow,
      workflow_oauth_token: 'test-oauth-token',
      workflow_service_token: 'test-service-token',
      workflow_metadata: { key: 'val' }.to_json
    }
  end

  shared_examples "success" do
    it 'creates a workload to execute workflow with the correct definition' do
      shadowed_project = project
      expect(Ci::Workloads::RunWorkloadService).to receive(:new) do |project:, **_kwargs|
        expect(project).to eq(shadowed_project)
      end.and_call_original

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
      settings_double = instance_double(::Ai::Setting, duo_workflow_service_account_user: service_account)
      allow(::Ai::Setting).to receive(:instance).and_return(settings_double)
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      # rubocop:disable RSpec/AnyInstanceOf -- not the next instance
      allow_any_instance_of(User).to receive(:allowed_to_use?).and_return(true)
      # rubocop:enable RSpec/AnyInstanceOf
      project.project_setting.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)

      mock_workload = instance_double(Ci::Workloads::Workload, id: 123)

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

    it 'passes source_branch to RunWorkloadService when provided' do
      local_params = params.merge(source_branch: 'feature-branch')
      service = described_class.new(workflow: workflow, params: local_params)

      expect(::Ci::Workloads::RunWorkloadService).to receive(:new).with(
        hash_including(source_branch: 'feature-branch')
      ).and_call_original

      expect(service.execute).to be_success
    end

    it 'passes nil when source_branch not provided' do
      expect(::Ci::Workloads::RunWorkloadService).to receive(:new).with(
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
        allow(duo_config).to receive_messages(valid?: true, default_image: custom_image)
      end

      context 'when workflow has no image specified' do
        let(:image) { nil }

        it 'uses the configured image from .gitlab/duo/agent-config.yml' do
          expect(Ci::Workloads::RunWorkloadService).to receive(:new) do |workload_definition:, **_kwargs|
            expect(workload_definition.image).to eq(custom_image)
          end.and_call_original

          expect(execute).to be_success
        end
      end

      context 'when workflow already has an image specified' do
        let(:image) { 'workflow-specific-image:latest' }

        it 'prefers the workflow image over the configured image' do
          expect(Ci::Workloads::RunWorkloadService).to receive(:new) do |workload_definition:, **_kwargs|
            expect(workload_definition.image).to eq(image)
          end.and_call_original

          expect(execute).to be_success
        end
      end
    end

    context 'when .gitlab/duo/agent-config.yml exists but has no default_image' do
      before do
        allow(duo_config).to receive_messages(valid?: true, default_image: nil)
      end

      let(:image) { nil }

      it 'falls back to the default IMAGE constant' do
        expect(Ci::Workloads::RunWorkloadService).to receive(:new) do |workload_definition:, **_kwargs|
          expect(workload_definition.image).to eq(described_class::IMAGE)
        end.and_call_original

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
      allow(duo_config).to receive_messages(valid?: true, default_image: config_image)
    end

    context 'when workflow image is present' do
      let(:image) { workflow_image }

      it 'uses the workflow image' do
        expect(Ci::Workloads::RunWorkloadService).to receive(:new) do |workload_definition:, **_kwargs|
          expect(workload_definition.image).to eq(workflow_image)
        end.and_call_original

        expect(execute).to be_success
      end
    end

    context 'when only config image is present' do
      let(:image) { nil }

      it 'uses the config image' do
        expect(Ci::Workloads::RunWorkloadService).to receive(:new) do |workload_definition:, **_kwargs|
          expect(workload_definition.image).to eq(config_image)
        end.and_call_original

        expect(execute).to be_success
      end
    end

    context 'when neither workflow nor config image are present' do
      let(:image) { nil }

      before do
        allow(duo_config).to receive(:default_image).and_return(nil)
      end

      it 'uses the default IMAGE constant' do
        expect(Ci::Workloads::RunWorkloadService).to receive(:new) do |workload_definition:, **_kwargs|
          expect(workload_definition.image).to eq(described_class::IMAGE)
        end.and_call_original

        expect(execute).to be_success
      end
    end
  end
end
