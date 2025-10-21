# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::UpdateWorkflowStatusEventWorker, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be(:workload) { create(:ci_workload, project: project, pipeline: pipeline) }
  let(:status) { 'finished' }
  let(:data) do
    { workload_id: workload.id, status: status }
  end

  let(:event) { Ci::Workloads::WorkloadFinishedEvent.new(data: data) }

  it_behaves_like 'subscribes to event'

  describe '#handle_event' do
    subject(:handle_event) { consume_event(subscriber: described_class, event: event) }

    context 'when workload cannot be found' do
      let(:data) do
        { workload_id: non_existing_record_id, status: status }
      end

      it 'does not call UpdateWorkflowStatusService' do
        expect(Ai::DuoWorkflows::UpdateWorkflowStatusService).not_to receive(:new)

        expect { handle_event }.not_to raise_error
      end
    end

    context 'when workload is found' do
      context 'when workflow cannot be found' do
        it 'does not call UpdateWorkflowStatusService' do
          expect(Ai::DuoWorkflows::UpdateWorkflowStatusService).not_to receive(:new)

          expect { handle_event }.not_to raise_error
        end
      end

      context 'when workflow is found' do
        using RSpec::Parameterized::TableSyntax
        let_it_be(:workflow) { create(:duo_workflows_workflow, project: project) }

        before do
          create(:duo_workflows_workload, workflow: workflow, workload: workload, project: project)
        end

        where(:workload_status, :expected_event) do
          'finished'  | 'finish'
          'failed'    | 'drop'
        end

        with_them do
          let(:status) { workload_status }

          it "calls UpdateWorkflowStatusService with #{params[:expected_event]} event" do
            expect(Ai::DuoWorkflows::UpdateWorkflowStatusService).to receive(:new)
              .with(workflow: workflow, status_event: expected_event, current_user: workflow.user).and_call_original

            handle_event
          end
        end
      end
    end
  end
end
