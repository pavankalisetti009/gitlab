# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::CreateAndStartWorkflowService, feature_category: :duo_agent_platform do
  subject(:result) { service.execute }

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:current_user) { create(:user, developer_of: project) }
  let_it_be(:service_account) { create(:service_account, maintainer_of: project) }
  let_it_be(:oauth_token) { create(:oauth_access_token, user: current_user, scopes: [:api]) }

  let(:goal) { 'Custom goal' }
  let(:source_branch) { 'feature/add-workflow' }
  let(:workflow_definition) { 'flow_name/experimental' }
  let(:workflow_params) { {} }
  let(:service) do
    described_class.new(
      container: project,
      current_user: current_user,
      goal: goal,
      source_branch: source_branch,
      workflow_definition: workflow_definition,
      workflow_params: workflow_params
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

  shared_examples_for 'failure' do |reason, message|
    it 'does not create a workload to execute workflow', :aggregate_failures do
      expect(result).to be_error
      expect(result.message).to eq(message)
      expect(result.reason).to eq(reason)
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
    before do
      ::Ai::Setting.instance.update!(duo_workflow_service_account_user: service_account)

      project.project_setting.update!(
        duo_features_enabled: true,
        duo_remote_flows_enabled: true
      )

      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(current_user, :duo_workflow, project).and_return(true)
      allow(Ability).to receive(:allowed?).with(current_user, :execute_duo_workflow_in_ci, anything).and_return(true)
    end

    it 'creates the workflow and starts a workload to execute with the correct definition', :aggregate_failures do
      expect(result).to be_success

      workflow_id = result.payload[:workflow_id]
      workload_id = result.payload[:workload_id]

      workflow = Ai::DuoWorkflows::Workflow.find_by(id: workflow_id)
      expect(workflow).to be_a(Ai::DuoWorkflows::Workflow)

      expect(workload_id).not_to be_nil
      expect(workflow.workflows_workloads.first).to have_attributes(project_id: project.id, workload_id: workload_id)

      workload = Ci::Workloads::Workload.find_by(id: [workload_id])
      expect(workload.branch_name).to start_with('workloads/')
    end
  end
end
