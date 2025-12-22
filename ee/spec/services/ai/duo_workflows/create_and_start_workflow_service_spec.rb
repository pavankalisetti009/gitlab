# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::CreateAndStartWorkflowService, feature_category: :duo_agent_platform do
  subject(:result) { service.execute }

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:current_user) { create(:user, developer_of: project) }
  let_it_be(:instance_wide_duo_developer) { create(:service_account, maintainer_of: project) }
  let_it_be(:oauth_token) { create(:oauth_access_token, user: current_user, scopes: [:api]) }

  let(:goal) { 'Custom goal' }
  let(:source_branch) { 'feature/add-workflow' }
  let(:workflow_definition) do
    ::Ai::DuoWorkflows::WorkflowDefinition.new(
      name: 'flow_name/experimental',
      workflow_definition: 'flow_name/experimental'
    )
  end

  let(:service) do
    described_class.new(
      container: project,
      current_user: current_user,
      goal: goal,
      source_branch: source_branch,
      workflow_definition: workflow_definition
    )
  end

  let(:workflow_service_token_result) do
    ServiceResponse.success(
      payload: { token: 'foo' }
    )
  end

  let(:workflow_oauth_token_result) do
    ServiceResponse.success(
      payload: { oauth_access_token: oauth_token }
    )
  end

  shared_examples 'failure' do |reason, message|
    it 'does not create a workload to execute workflow', :aggregate_failures do
      expect(result).to be_error
      expect(result.message).to eq(message)
      expect(result.reason).to eq(reason)
    end
  end

  shared_context 'with valid workflow settings' do
    before do
      project.project_setting.update!(
        duo_features_enabled: true,
        duo_remote_flows_enabled: true
      )

      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(current_user, :duo_workflow, project).and_return(true)
      allow(Ability).to receive(:allowed?).with(current_user, :execute_duo_workflow_in_ci, anything).and_return(true)
      allow(Ability).to receive(:allowed?).with(current_user, :read_ai_catalog_item_consumer, anything).and_return(true)
    end
  end

  before do
    allow_next_instance_of(::Ai::DuoWorkflows::WorkflowContextGenerationService) do |service|
      allow(service)
        .to receive_messages(
          generate_workflow_token: workflow_service_token_result,
          generate_oauth_token_with_composite_identity_support: workflow_oauth_token_result
        )
    end

    allow_next_instance_of(Ai::UsageQuotaService) do |instance|
      allow(instance).to receive(:execute).and_return(
        ServiceResponse.success
      )
    end

    allow(::Ai::DuoWorkflow).to receive(:available?).and_return(true)

    ::Ai::Setting.instance.update!(duo_workflow_service_account_user: instance_wide_duo_developer)
  end

  describe '#workflow_definition_reference' do
    it 'returns foundational_flow_reference for foundational workflows' do
      workflow_def = ::Ai::DuoWorkflows::WorkflowDefinition.new(
        name: 'code_review/v1',
        foundational_flow_reference: 'code_review/v1'
      )

      service = described_class.new(
        container: project,
        current_user: current_user,
        goal: goal,
        source_branch: source_branch,
        workflow_definition: workflow_def
      )

      expect(service.send(:workflow_definition_reference)).to eq('code_review/v1')
    end

    it 'returns workflow_definition for non-foundational workflows' do
      workflow_def = ::Ai::DuoWorkflows::WorkflowDefinition.new(
        name: 'resolve_sast_vulnerability/v1',
        workflow_definition: 'resolve_sast_vulnerability/v1'
      )

      service = described_class.new(
        container: project,
        current_user: current_user,
        goal: goal,
        source_branch: source_branch,
        workflow_definition: workflow_def
      )

      expect(service.send(:workflow_definition_reference)).to eq('resolve_sast_vulnerability/v1')
    end

    it 'prioritizes foundational_flow_reference when both are present' do
      workflow_def = ::Ai::DuoWorkflows::WorkflowDefinition.new(
        name: 'code_review/v1',
        foundational_flow_reference: 'code_review/v1',
        workflow_definition: 'code_review/v1'
      )

      service = described_class.new(
        container: project,
        current_user: current_user,
        goal: goal,
        source_branch: source_branch,
        workflow_definition: workflow_def
      )

      expect(service.send(:workflow_definition_reference)).to eq('code_review/v1')
    end
  end

  context 'when workflow definition is not provided' do
    let(:workflow_definition) { nil }

    include_examples 'failure', :invalid_workflow_definition, 'Workflow definition cannot be blank'
  end

  context 'when source branch is not provided' do
    let(:source_branch) { nil }

    include_examples 'failure', :invalid_source_branch, 'Source branch cannot be blank'
  end

  context 'when workflow token could not be generated' do
    let(:workflow_service_token_result) do
      ServiceResponse.error(message: 'Could not create workflow token')
    end

    include_examples 'failure', :invalid_duo_workflow_token, 'Could not obtain Duo Workflow token'
  end

  context 'when oauth token could not be generated' do
    let(:workflow_oauth_token_result) do
      ServiceResponse.error(message: 'Could not create workflow token')
    end

    include_examples 'failure', :invalid_oauth_token, 'Could not obtain authentication token'
  end

  context 'when workflow info is valid' do
    include_context 'with valid workflow settings'

    it 'creates the workflow and starts a workload to execute with the correct definition', :aggregate_failures do
      expect(result).to be_success

      workflow_id = result.payload[:workflow_id]
      workload_id = result.payload[:workload_id]

      workflow = Ai::DuoWorkflows::Workflow.find_by(id: workflow_id)
      expect(workflow).to be_a(Ai::DuoWorkflows::Workflow)
      expect(workflow.workflow_definition).to eq('flow_name/experimental')

      expect(workload_id).not_to be_nil
      expect(workflow.workflows_workloads.first).to have_attributes(project_id: project.id, workload_id: workload_id)

      workload = Ci::Workloads::Workload.find_by(id: [workload_id])
      expect(workload.branch_name).to start_with('refs/workloads/')
      expect(workload.pipeline.user).to eq(instance_wide_duo_developer)
    end
  end

  context 'with a foundational workflow' do
    include_context 'with valid workflow settings'

    let_it_be(:flow) { create(:ai_catalog_item, :with_foundational_flow_reference, :public, :flow, project: project) }
    let_it_be(:foundational_flow_reference) { flow.foundational_flow_reference }
    let_it_be(:workflow_definition) do
      ::Ai::DuoWorkflows::WorkflowDefinition.new(
        name: "#{foundational_flow_reference}/v1",
        foundational_flow_reference: foundational_flow_reference
      )
    end

    let_it_be(:group_level_duo_developer) do
      create(:user, :service_account) do |user|
        create(:user_detail, user: user, provisioned_by_group: group)
      end
    end

    before do
      project.add_member(group_level_duo_developer, :developer)
    end

    context 'when new workflow configuration is enabled' do
      before do
        create(:ai_catalog_item_consumer, group: group, item: flow, service_account: group_level_duo_developer)
      end

      it 'uses the group-level service account' do
        expect(result).to be_success

        workload_id = result.payload[:workload_id]
        workload = Ci::Workloads::Workload.find_by(id: [workload_id])

        expect(workload.pipeline.user).to eq(group_level_duo_developer)
      end

      it 'creates workflow with foundational_flow_reference as workflow_definition' do
        expect(result).to be_success

        workflow_id = result.payload[:workflow_id]
        workflow = Ai::DuoWorkflows::Workflow.find_by(id: workflow_id)

        expect(workflow.workflow_definition).to eq(foundational_flow_reference)
      end
    end

    context 'when new workflow configuration is not enabled' do
      it 'uses the instance-wide service account' do
        expect(result).to be_success

        workload_id = result.payload[:workload_id]
        workload = Ci::Workloads::Workload.find_by(id: [workload_id])

        expect(workload.pipeline.user).to eq(instance_wide_duo_developer)
      end
    end
  end
end
