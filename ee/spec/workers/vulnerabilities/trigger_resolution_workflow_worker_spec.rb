# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::TriggerResolutionWorkflowWorker, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:vulnerability) { create(:vulnerability, project: project, author: user) }
  let_it_be(:finding) { create(:vulnerabilities_finding, project: project, vulnerability: vulnerability) }
  let_it_be(:vulnerability_flag) { create(:vulnerabilities_flag, finding: finding, confidence_score: 0.5) }

  let(:worker) { described_class.new }
  let(:vulnerability_flag_id) { vulnerability_flag.id }
  let(:workflow_definition) { ::Ai::DuoWorkflows::WorkflowDefinition['resolve_sast_vulnerability/v1'] }

  describe '#perform' do
    let(:workflow) { create(:duo_workflows_workflow, project: project, user: user) }
    let(:workflow_service) { instance_double(::Ai::DuoWorkflows::CreateAndStartWorkflowService) }
    let(:service_result) { ServiceResponse.success(payload: { workflow_id: workflow.id, workload_id: 456 }) }

    before do
      allow(::Ai::DuoWorkflows::CreateAndStartWorkflowService).to receive(:new).and_return(workflow_service)
      allow(workflow_service).to receive(:execute).and_return(service_result)
    end

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [vulnerability_flag_id] }
    end

    context 'when vulnerability flag exists' do
      context 'when confidence score is below threshold' do
        before do
          vulnerability_flag.update!(confidence_score: 0.5)
        end

        context 'when feature flag is disabled' do
          before do
            stub_feature_flags(enable_vulnerability_resolution: false)
          end

          it 'returns early without calling the workflow service' do
            expect(::Ai::DuoWorkflows::CreateAndStartWorkflowService).not_to receive(:new)
            expect(Gitlab::AppLogger).not_to receive(:error)

            worker.perform(vulnerability_flag_id)
          end
        end

        context 'when feature flag is enabled' do
          it 'creates and executes the workflow service with correct parameters' do
            expect(::Ai::DuoWorkflows::CreateAndStartWorkflowService).to receive(:new).with(
              container: project,
              current_user: user,
              workflow_definition: workflow_definition,
              goal: vulnerability.id.to_s,
              source_branch: project.default_branch
            ).and_return(workflow_service)

            worker.perform(vulnerability_flag_id)
          end

          context 'when workflow service succeeds' do
            it 'creates a triggered workflow record' do
              expect do
                worker.perform(vulnerability_flag_id)
              end.to change { Vulnerabilities::TriggeredWorkflow.count }.by(1)
            end

            it 'creates triggered workflow with correct attributes' do
              worker.perform(vulnerability_flag_id)

              triggered_workflow = Vulnerabilities::TriggeredWorkflow.last
              expect(triggered_workflow).to be_present
              expect(triggered_workflow.vulnerability_occurrence_id).to eq(finding.id)
              expect(triggered_workflow.workflow_id).to eq(workflow.id)
              expect(triggered_workflow.workflow_name).to eq("resolve_sast_vulnerability")
            end

            context 'when creating triggered workflow record fails' do
              let(:error) { ActiveRecord::RecordInvalid.new }

              before do
                allow(Vulnerabilities::TriggeredWorkflow).to receive(:create!).and_raise(error)
              end

              it 'tracks the exception to error tracking' do
                expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
                  error,
                  vulnerability_id: finding.vulnerability_id,
                  workflow_id: workflow.id
                )

                worker.perform(vulnerability_flag_id)
              end

              it 'does not raise the exception' do
                expect { worker.perform(vulnerability_flag_id) }.not_to raise_error
              end
            end
          end

          context 'when workflow service fails' do
            let(:service_result) do
              ServiceResponse.error(message: 'Workflow creation failed', reason: :invalid_params)
            end

            it 'logs error message with failure details and raises exception' do
              expect(Gitlab::AppLogger).to receive(:error).with(
                message: 'Failed to create and start workflow for vulnerability resolution',
                vulnerability_flag_id: vulnerability_flag.id,
                finding_id: finding.id,
                error: 'Workflow creation failed',
                reason: :invalid_params
              )

              expect { worker.perform(vulnerability_flag_id) }.to raise_error(
                described_class::StartWorkflowServiceError,
                'Failed to start workflow for vulnerability resolution: Workflow creation failed'
              )
            end

            it 'does not create a triggered workflow record' do
              expect do
                worker.perform(vulnerability_flag_id)
              rescue StandardError
                described_class::StartWorkflowServiceError
              end.not_to change { Vulnerabilities::TriggeredWorkflow.count }
            end
          end
        end
      end

      context 'when confidence score is at threshold' do
        before do
          vulnerability_flag.update!(confidence_score: 0.6)
        end

        it 'returns early without calling the workflow service' do
          expect(::Ai::DuoWorkflows::CreateAndStartWorkflowService).not_to receive(:new)
          expect(Gitlab::AppLogger).not_to receive(:error)

          worker.perform(vulnerability_flag_id)
        end
      end

      context 'when confidence score is above threshold' do
        before do
          vulnerability_flag.update!(confidence_score: 0.8)
        end

        it 'returns early without calling the workflow service' do
          expect(::Ai::DuoWorkflows::CreateAndStartWorkflowService).not_to receive(:new)
          expect(Gitlab::AppLogger).not_to receive(:error)

          worker.perform(vulnerability_flag_id)
        end
      end
    end

    context 'when vulnerability flag does not exist' do
      let(:vulnerability_flag_id) { non_existing_record_id }

      it 'returns early without calling the workflow service' do
        expect(::Ai::DuoWorkflows::CreateAndStartWorkflowService).not_to receive(:new)
        expect(Gitlab::AppLogger).not_to receive(:error)

        worker.perform(vulnerability_flag_id)
      end
    end

    context 'when trigger_workflow raises an exception' do
      let(:error) { StandardError.new('Service error') }

      before do
        vulnerability_flag.update!(confidence_score: 0.5)
        allow(::Ai::DuoWorkflows::CreateAndStartWorkflowService).to receive(:new).and_raise(error)
      end

      it 'logs and raises the exception' do
        expect(Gitlab::ErrorTracking).to receive(:log_and_raise_exception).with(
          error,
          vulnerability_flag_id: vulnerability_flag_id
        ).and_call_original

        expect { worker.perform(vulnerability_flag_id) }.to raise_error(error)
      end
    end
  end
end
