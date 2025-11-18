# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_finding, project: project, author: user) }

  let(:worker) { described_class.new }
  let(:vulnerability_id) { vulnerability.id }
  let(:workflow_definition) { ::Ai::DuoWorkflows::WorkflowDefinition['sast_fp_detection/v1'] }

  describe '#perform' do
    let(:workflow) { create(:duo_workflows_workflow, user: user, project: project, environment: :web) }
    let(:workflow_service) { instance_double(::Ai::DuoWorkflows::CreateAndStartWorkflowService) }
    let(:service_result) { ServiceResponse.success(payload: { workflow_id: workflow.id, workload_id: 456 }) }

    before do
      allow(::Ai::DuoWorkflows::CreateAndStartWorkflowService).to receive(:new).and_return(workflow_service)
      allow(workflow_service).to receive(:execute).and_return(service_result)
    end

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [vulnerability_id] }
    end

    context 'when vulnerability exist' do
      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(enable_vulnerability_fp_detection: false)
        end

        it 'returns early without calling the workflow service' do
          expect(::Ai::DuoWorkflows::CreateAndStartWorkflowService).not_to receive(:new)
          expect(Gitlab::AppLogger).not_to receive(:error)

          worker.perform(vulnerability_id)
        end
      end

      context 'when feature flag is enabled' do
        it 'creates and executes the workflow service with correct parameters' do
          expect(::Ai::DuoWorkflows::CreateAndStartWorkflowService).to receive(:new).with(
            container: project,
            current_user: user,
            workflow_definition: workflow_definition,
            goal: vulnerability_id.to_s,
            source_branch: project.default_branch
          )

          worker.perform(vulnerability_id)
        end

        context 'when workflow service succeeds' do
          it 'creates a triggered workflow record with correct attributes' do
            expect { worker.perform(vulnerability_id) }
              .to change { ::Vulnerabilities::TriggeredWorkflow.count }.by(1)

            triggered_workflow = ::Vulnerabilities::TriggeredWorkflow.last
            expect(triggered_workflow.vulnerability_occurrence).to eq(vulnerability.finding)
            expect(triggered_workflow.workflow_id).to eq(workflow.id)
            expect(triggered_workflow.workflow_name).to eq('sast_fp_detection')
          end

          it 'does not log any errors' do
            expect(Gitlab::AppLogger).not_to receive(:error)

            worker.perform(vulnerability_id)
          end

          context 'when creation of triggered workflow fails' do
            let_it_be(:other_project) { create(:project, :repository) }
            let(:other_workflow) do
              create(:duo_workflows_workflow, user: user, project: other_project, environment: :web)
            end

            let(:service_result) do
              ServiceResponse.success(payload: { workflow_id: other_workflow.id, workload_id: 456 })
            end

            it 'logs error message and sends to Sentry' do
              expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
                an_instance_of(ActiveRecord::RecordInvalid),
                vulnerability_id: vulnerability.id,
                workflow_id: other_workflow.id
              )

              worker.perform(vulnerability_id)
            end
          end
        end

        context 'when workflow service fails' do
          let(:service_result) do
            ServiceResponse.error(message: 'Workflow creation failed', reason: :invalid_params)
          end

          it 'logs error message and raise StartWorkflowServiceError' do
            expect(Gitlab::AppLogger).to receive(:error).with(
              message: 'Failed to call SAST workflow service for vulnerability',
              vulnerability_id: vulnerability.id,
              project_id: project.id,
              error: 'Workflow creation failed',
              reason: :invalid_params
            )

            expect { worker.perform(vulnerability_id) }
              .to raise_error(Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker::StartWorkflowServiceError)
          end

          it 'does not create a triggered workflow record' do
            expect do
              expect { worker.perform(vulnerability.id) }.to raise_error(
                Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker::StartWorkflowServiceError
              )
            end.not_to change { ::Vulnerabilities::TriggeredWorkflow.count }
          end
        end
      end
    end

    context 'when vulnerability does not exist' do
      let(:vulnerability_id) { non_existing_record_id }

      it 'returns early without calling the workflow service' do
        expect(::Ai::DuoWorkflows::CreateAndStartWorkflowService).not_to receive(:new)
        expect(Gitlab::AppLogger).not_to receive(:error)

        worker.perform(vulnerability_id)
      end
    end

    context 'when workflow service raises an exception' do
      let(:error) { StandardError.new('Service error') }

      before do
        allow(workflow_service).to receive(:execute).and_raise(error)
      end

      it 'logs and raises the exception' do
        expect(Gitlab::ErrorTracking).to receive(:log_and_raise_exception).with(
          error,
          vulnerability_id: vulnerability_id
        )

        worker.perform(vulnerability_id)
      end
    end
  end
end
