# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:vulnerability) { create(:vulnerability, project: project, author: user) }

  let(:worker) { described_class.new }
  let(:vulnerability_id) { vulnerability.id }
  let(:workflow_definition) { ::Ai::DuoWorkflows::WorkflowDefinition['sast_fp_detection/v1'] }

  describe '#perform' do
    let(:workflow_service) { instance_double(::Ai::DuoWorkflows::CreateAndStartWorkflowService) }
    let(:service_result) { ServiceResponse.success(payload: { workflow_id: 123, workload_id: 456 }) }

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

        context 'when workflow service fails' do
          let(:service_result) do
            ServiceResponse.error(message: 'Workflow creation failed', reason: :invalid_params)
          end

          it 'logs error message with failure details' do
            expect(Gitlab::AppLogger).to receive(:error).with(
              message: 'Failed to call SAST workflow service for vulnerability',
              vulnerability_id: vulnerability.id,
              project_id: project.id,
              error: 'Workflow creation failed',
              reason: :invalid_params
            )

            worker.perform(vulnerability_id)
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

      it 'logs the exception to error tracking' do
        expect(Gitlab::ErrorTracking).to receive(:log_exception).with(
          error,
          vulnerability_id: vulnerability_id
        )

        worker.perform(vulnerability_id)
      end
    end
  end
end
