# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'UpdateDuoWorkflowToolCallApprovals', feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:workflow) { create(:duo_workflows_workflow, project: project, user: user) }

  let(:tool_name) { 'run_command' }
  let(:call_args) { { 'command' => 'ls -la', 'working_dir' => '/home' } }
  let(:service_instance) { instance_double(::Ai::DuoWorkflows::UpdateToolCallApprovalsService) }

  let(:mutation) do
    graphql_mutation(
      :update_duo_workflow_tool_call_approvals,
      {
        workflow_id: workflow.to_global_id.to_s,
        tool_name: tool_name,
        tool_call_args: call_args.to_json
      },
      <<~GQL
        workflow {
          id
          toolCallApprovals
        }
        errors
      GQL
    )
  end

  subject(:request) { post_graphql_mutation(mutation, current_user: user) }

  context 'when user has permission to update workflow' do
    before_all do
      project.add_maintainer(user)
    end

    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user, :update_duo_workflow, workflow).and_return(true)
      allow(Ability).to receive(:allowed?).with(user, :read_duo_workflow, workflow).and_return(true)
    end

    it 'calls the service with correct parameters and returns success', :aggregate_failures do
      expect(::Ai::DuoWorkflows::UpdateToolCallApprovalsService).to receive(:new).with(
        workflow: workflow,
        tool_name: tool_name,
        tool_call_args: call_args.to_json,
        current_user: user
      ).and_return(service_instance)

      expect(service_instance).to receive(:execute).and_return(
        ServiceResponse.success(payload: { workflow: workflow })
      )

      request

      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_errors).to be_blank
      expect(graphql_data_at(:update_duo_workflow_tool_call_approvals, :errors)).to be_empty
      workflow_id = graphql_data_at(:update_duo_workflow_tool_call_approvals, :workflow, :id)
      expect(workflow_id).to eq(workflow.to_global_id.to_s)
    end

    context 'when service returns an error' do
      it 'returns the error message', :aggregate_failures do
        allow(::Ai::DuoWorkflows::UpdateToolCallApprovalsService).to receive(:new).and_return(service_instance)
        allow(service_instance).to receive(:execute).and_return(
          ServiceResponse.error(message: 'Failed to update tool_call_approvals')
        )

        request

        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_errors).to be_blank
        expect(graphql_data_at(:update_duo_workflow_tool_call_approvals, :workflow)).to be_nil
        expect(graphql_data_at(:update_duo_workflow_tool_call_approvals, :errors))
          .to include('Failed to update tool_call_approvals')
      end
    end
  end

  context 'when user lacks permission' do
    let_it_be(:other_user) { create(:user) }

    subject(:request) { post_graphql_mutation(mutation, current_user: other_user) }

    it 'returns authorization error without calling the service', :aggregate_failures do
      expect(::Ai::DuoWorkflows::UpdateToolCallApprovalsService).not_to receive(:new)

      request

      expect(graphql_errors).not_to be_blank
      expect(graphql_errors.first['message']).to include("don't have permission")
    end
  end

  context 'when workflow does not exist' do
    let(:mutation) do
      graphql_mutation(
        :update_duo_workflow_tool_call_approvals,
        {
          workflow_id: "gid://gitlab/Ai::DuoWorkflows::Workflow/#{non_existing_record_id}",
          tool_name: tool_name,
          tool_call_args: call_args.to_json
        },
        <<~GQL
            errors
        GQL
      )
    end

    it 'returns not found error without calling the service', :aggregate_failures do
      expect(::Ai::DuoWorkflows::UpdateToolCallApprovalsService).not_to receive(:new)

      request

      expect(graphql_errors).not_to be_blank
    end
  end
end
