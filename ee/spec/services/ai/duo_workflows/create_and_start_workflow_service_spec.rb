# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::CreateAndStartWorkflowService, feature_category: :duo_agent_platform do
  subject(:result) { service.execute }

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:current_user) { create(:user, developer_of: project) }
  let_it_be(:oauth_token) { create(:oauth_access_token, user: current_user, scopes: [:api]) }
  let_it_be(:catalog_item) do
    create(:ai_catalog_item, :with_foundational_flow_reference, :public, :flow, project: project)
  end

  let_it_be(:instance_wide_duo_developer) do
    create(:user, :service_account)
  end

  let_it_be(:group_level_service_account) do
    create(:user, :service_account) do |user|
      create(:user_detail, user: user, provisioned_by_group: group)
    end
  end

  let(:goal) { 'Custom goal' }
  let(:source_branch) { 'feature/add-workflow' }

  let(:workflow_definition) do
    ::Ai::Catalog::FoundationalFlow.new(
      name: catalog_item.foundational_flow_reference,
      foundational_flow_reference: catalog_item.foundational_flow_reference
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

  let(:resolve_service_account_result) do
    ServiceResponse.success(
      payload: { service_account: group_level_service_account }
    )
  end

  shared_examples 'failure' do |reason, message|
    it 'does not create a workload to execute workflow', :aggregate_failures do
      expect(result).to be_error
      expect(result.message).to eq(message)
      expect(result.reason).to eq(reason)
    end
  end

  shared_examples 'success' do
    it 'creates the workflow and starts a workload to execute with the correct definition', :aggregate_failures do
      expect(result).to be_success

      workflow_id = result.payload[:workflow_id]
      workload_id = result.payload[:workload_id]

      workflow = Ai::DuoWorkflows::Workflow.find_by(id: workflow_id)
      expect(workflow).to be_a(Ai::DuoWorkflows::Workflow)

      expect(workload_id).not_to be_nil
      expect(workflow.workflows_workloads.first).to have_attributes(project_id: project.id, workload_id: workload_id)

      workload = Ci::Workloads::Workload.find_by(id: workload_id)
      expect(workload.branch_name).to start_with('refs/workloads/')
      expect(workload.pipeline.user).to eq(group_level_service_account)
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

    allow_next_instance_of(::Ai::Catalog::ItemConsumers::ResolveServiceAccountService) do |service|
      allow(service).to receive(:execute).and_return(resolve_service_account_result)
    end

    allow_next_instance_of(Ai::UsageQuotaService) do |instance|
      allow(instance).to receive(:execute).and_return(
        ServiceResponse.success
      )
    end

    allow(::Ai::DuoWorkflow).to receive(:available?).and_return(true)

    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?).with(current_user, :duo_workflow, project).and_return(true)
    allow(Ability).to receive(:allowed?).with(current_user, :execute_duo_workflow_in_ci, anything).and_return(true)
    allow(Ability).to receive(:allowed?).with(current_user, :read_ai_catalog_item_consumer, anything).and_return(true)

    project.project_setting.update!(
      duo_features_enabled: true,
      duo_remote_flows_enabled: true
    )

    project.add_member(group_level_service_account, :developer)

    ::Ai::Setting.instance.update!(duo_workflow_service_account_user: instance_wide_duo_developer)
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

  context 'when a flow does not have an associated catalog item' do
    before do
      allow(workflow_definition).to receive(:foundational_flow_reference).and_return(nil)
    end

    include_examples 'failure', :invalid_service_account, 'Could not resolve the service account for this flow'
  end

  context 'when service account could not be resolved' do
    let(:resolve_service_account_result) do
      ServiceResponse.error(message: 'Could not resolve service account')
    end

    include_examples 'failure', :invalid_service_account, 'Could not resolve the service account for this flow'
  end

  context 'with a configured foundational flow' do
    include_examples 'success'
  end
end
