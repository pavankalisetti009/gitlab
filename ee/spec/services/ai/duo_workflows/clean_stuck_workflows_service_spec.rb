# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::CleanStuckWorkflowsService, feature_category: :duo_agent_platform do
  subject(:execute) { described_class.new.execute }

  describe '#execute' do
    using RSpec::Parameterized::TableSyntax

    where(:updated_when, :current_status, :expected_status) do
      "recent" | :created                      | :created
      "recent" | :running                      | :running
      "recent" | :paused                       | :paused
      "recent" | :finished                     | :finished
      "recent" | :failed                       | :failed
      "recent" | :stopped                      | :stopped
      "recent" | :input_required               | :input_required
      "recent" | :plan_approval_required       | :plan_approval_required
      "recent" | :tool_call_approval_required  | :tool_call_approval_required
      "old"    | :created                      | :failed
      "old"    | :running                      | :failed
      "old"    | :paused                       | :paused
      "old"    | :finished                     | :finished
      "old"    | :failed                       | :failed
      "old"    | :stopped                      | :stopped
      "old"    | :input_required               | :input_required
      "old"    | :plan_approval_required       | :plan_approval_required
      "old"    | :tool_call_approval_required  | :tool_call_approval_required
    end

    with_them do
      action = params[:current_status] == params[:expected_status] ? "keeps" : "changes"
      test_case_name = "#{action} #{params[:updated_when]} workflow status: " \
        "#{params[:current_status]} → #{params[:expected_status]}"
      it test_case_name do
        updated_at = updated_when == "old" ? 2.days.ago : 1.minute.ago
        workflow = create(:duo_workflows_workflow, status: status_enum(current_status), updated_at: updated_at)
        expect(workflow.reload.status).to eq(status_enum(current_status))

        if current_status != expected_status
          expect { execute }.to trigger_internal_events("cleanup_stuck_agent_platform_session")
                                  .with(category: "Ai::DuoWorkflows::CleanStuckWorkflowsService",
                                    user: workflow.user,
                                    project: workflow.project,
                                    additional_properties: {
                                      label: workflow.workflow_definition,
                                      value: workflow.id,
                                      property: "failed"
                                    })
        end

        expect(workflow.reload.status).to eq(status_enum(expected_status))
      end
    end
  end

  def status_enum(status)
    Ai::DuoWorkflows::Workflow.state_machine.states[status].value
  end
end
