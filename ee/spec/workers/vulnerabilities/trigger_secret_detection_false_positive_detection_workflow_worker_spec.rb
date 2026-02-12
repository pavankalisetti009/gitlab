# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::TriggerSecretDetectionFalsePositiveDetectionWorkflowWorker, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:vulnerability) do
    create(:vulnerability, :with_finding, report_type: :secret_detection, project: project, author: user)
  end

  let(:worker) { described_class.new }
  let(:vulnerability_id) { vulnerability.id }
  let(:workflow_definition) { 'secrets_fp_detection/v1' }

  describe '#perform' do
    let(:workflow) { create(:duo_workflows_workflow, user: user, project: project, environment: :web) }
    let(:execute_service) { instance_double(::Ai::Catalog::Flows::ExecuteService) }
    let(:service_result) { ServiceResponse.success(payload: { workflow_id: workflow.id, workload_id: 456 }) }
    let(:consumer) { create(:ai_catalog_item_consumer, project: project) }

    before do
      allow(::Ai::Catalog::ItemConsumersFinder).to receive(:new).and_return(
        instance_double(::Ai::Catalog::ItemConsumersFinder, execute: [consumer])
      )
      allow(::Ai::Catalog::Flows::ExecuteService).to receive(:new).and_return(execute_service)
      allow(execute_service).to receive(:execute).and_return(service_result)
    end

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [vulnerability_id] }
    end

    context 'when vulnerability exist' do
      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(duo_secret_detection_false_positive: false)
        end

        it 'returns early without calling the workflow service' do
          expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)
          expect(Gitlab::AppLogger).not_to receive(:error)

          worker.perform(vulnerability_id)
        end
      end

      context 'when feature flag is enabled' do
        it 'finds the consumer with correct parameters' do
          expect(::Ai::Catalog::ItemConsumersFinder).to receive(:new).with(
            project.first_owner,
            params: {
              project_id: project.id,
              item_type: Ai::Catalog::Item::FLOW_TYPE,
              foundational_flow_reference: workflow_definition
            }
          )

          worker.perform(vulnerability_id)
        end

        it 'creates and executes the flow service with correct parameters' do
          expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
            project: project,
            current_user: project.first_owner,
            params: {
              item_consumer: consumer,
              service_account: nil,
              execute_workflow: true,
              event_type: 'sidekiq_worker',
              user_prompt: vulnerability_id.to_s
            }
          )

          worker.perform(vulnerability_id)
        end

        context 'when consumer has parent item consumer with service account' do
          let_it_be(:group) { create(:group) }
          let_it_be(:project_with_group) { create(:project, :repository, group: group) }

          let(:vulnerability_with_group) do
            create(:vulnerability, :with_finding, report_type: :secret_detection, project: project_with_group,
              author: user)
          end

          let(:service_account) { create(:user, :service_account, provisioned_by_group: group) }
          let(:flow_item) { create(:ai_catalog_flow, public: true) }
          let!(:parent_consumer) do
            create(:ai_catalog_item_consumer, group: group, item: flow_item, service_account: service_account)
          end

          let(:consumer) do
            Ai::Catalog::ItemConsumer.create!(
              project: project_with_group,
              item: flow_item,
              parent_item_consumer: parent_consumer
            )
          end

          it 'uses service account from parent consumer' do
            expected_user = project_with_group.first_owner || user

            expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
              project: project_with_group,
              current_user: expected_user,
              params: {
                item_consumer: consumer,
                service_account: service_account,
                execute_workflow: true,
                event_type: 'sidekiq_worker',
                user_prompt: vulnerability_with_group.id.to_s
              }
            )

            worker.perform(vulnerability_with_group.id)
          end
        end

        context 'when consumer is nil' do
          before do
            allow(::Ai::Catalog::ItemConsumersFinder).to receive(:new).and_return(
              instance_double(::Ai::Catalog::ItemConsumersFinder, execute: [])
            )
          end

          it 'uses nil service account' do
            expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
              project: project,
              current_user: project.first_owner,
              params: {
                item_consumer: nil,
                service_account: nil,
                execute_workflow: true,
                event_type: 'sidekiq_worker',
                user_prompt: vulnerability_id.to_s
              }
            )

            worker.perform(vulnerability_id)
          end
        end

        context 'when workflow service succeeds' do
          it 'creates a triggered workflow record with correct attributes' do
            expect { worker.perform(vulnerability_id) }
              .to change { ::Vulnerabilities::TriggeredWorkflow.count }.by(1)

            triggered_workflow = ::Vulnerabilities::TriggeredWorkflow.last
            expect(triggered_workflow.vulnerability_occurrence).to eq(vulnerability.finding)
            expect(triggered_workflow.workflow_id).to eq(workflow.id)
            expect(triggered_workflow.workflow_name).to eq('secrets_fp_detection')
          end

          it 'tracks the internal event' do
            expect { worker.perform(vulnerability_id) }
              .to trigger_internal_events(
                'trigger_secret_detection_vulnerability_fp_detection_workflow'
              ).with(
                project: project,
                additional_properties: {
                  label: 'automatic',
                  value: vulnerability_id,
                  property: vulnerability.severity
                }
              )
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

            it 'does not track the event' do
              expect { worker.perform(vulnerability_id) }
                .not_to trigger_internal_events(
                  'trigger_secret_detection_vulnerability_fp_detection_workflow'
                )
            end
          end

          context 'when vulnerability has no finding' do
            let_it_be(:vulnerability_without_finding) do
              create(:vulnerability, report_type: :secret_detection, project: project, author: user)
            end

            it 'attempts to create a triggered workflow but fails validation due to missing finding' do
              expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
                an_instance_of(ActiveRecord::RecordInvalid),
                vulnerability_id: vulnerability_without_finding.id,
                workflow_id: workflow.id
              )

              expect { worker.perform(vulnerability_without_finding.id) }
                .not_to change { ::Vulnerabilities::TriggeredWorkflow.count }
            end

            it 'does not track the event when record creation fails' do
              allow(Gitlab::ErrorTracking).to receive(:track_exception)

              expect { worker.perform(vulnerability_without_finding.id) }
                .not_to trigger_internal_events(
                  'trigger_secret_detection_vulnerability_fp_detection_workflow'
                )
            end
          end
        end

        context 'when workflow service fails' do
          let(:service_result) do
            ServiceResponse.error(message: 'Workflow creation failed', reason: :invalid_params)
          end

          it 'logs error message and raise StartWorkflowServiceError' do
            expect(Gitlab::AppLogger).to receive(:error).with(
              message: 'Failed to call Secret Detection workflow service for vulnerability',
              vulnerability_id: vulnerability.id,
              project_id: project.id,
              error: 'Workflow creation failed',
              reason: :invalid_params
            )

            expect { worker.perform(vulnerability_id) }
              .to raise_error(
                Vulnerabilities::TriggerSecretDetectionFalsePositiveDetectionWorkflowWorker::StartWorkflowServiceError
              )
          end

          it 'does not create a triggered workflow record' do
            expect do
              expect { worker.perform(vulnerability.id) }.to raise_error(
                Vulnerabilities::TriggerSecretDetectionFalsePositiveDetectionWorkflowWorker::StartWorkflowServiceError
              )
            end.not_to change { ::Vulnerabilities::TriggeredWorkflow.count }
          end

          it 'does not track the event' do
            expect { worker.perform(vulnerability_id) }
              .to raise_error(
                Vulnerabilities::TriggerSecretDetectionFalsePositiveDetectionWorkflowWorker::StartWorkflowServiceError
              ).and not_trigger_internal_events(
                'trigger_secret_detection_vulnerability_fp_detection_workflow'
              )
          end
        end
      end
    end

    context 'when vulnerability does not exist' do
      let(:vulnerability_id) { non_existing_record_id }

      it 'returns early without calling the workflow service' do
        expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)
        expect(Gitlab::AppLogger).not_to receive(:error)

        worker.perform(vulnerability_id)
      end
    end

    context 'when workflow service raises an exception' do
      let(:error) { StandardError.new('Service error') }

      before do
        allow(execute_service).to receive(:execute).and_raise(error)
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
