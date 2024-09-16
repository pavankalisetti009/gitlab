# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanExecutionPolicies::CreatePipelineWorker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:security_orchestration_policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  let_it_be(:schedule) do
    create(:security_orchestration_policy_rule_schedule,
      security_orchestration_policy_configuration: security_orchestration_policy_configuration)
  end

  let(:project_id) { project.id }
  let(:current_user_id) { current_user.id }
  let(:branch) { 'production' }
  let(:actions) { [{ scan: 'dast' }] }
  let(:params) { { actions: actions, branch: branch } }
  let(:schedule_id) { schedule.id }
  let(:policy) { build(:scan_execution_policy, enabled: true, actions: [{ scan: 'dast' }]) }

  shared_examples_for 'does not call RuleScheduleService' do
    it do
      expect(Security::SecurityOrchestrationPolicies::RuleScheduleService).not_to receive(:new)

      run_worker
    end
  end

  shared_examples_for 'creates a new pipeline' do
    it 'delegates the pipeline creation to Security::SecurityOrchestrationPolicies::CreatePipelineService' do
      expect(::Security::SecurityOrchestrationPolicies::CreatePipelineService).to(
        receive(:new)
          .with(project: project, current_user: current_user, params: params)
          .and_call_original)

      run_worker
    end
  end

  shared_examples_for 'does not creates a new pipeline' do
    it 'does not invokes CreatePipelineService' do
      expect(::Security::SecurityOrchestrationPolicies::CreatePipelineService).not_to(
        receive(:new)
          .with(project: project, current_user: current_user, params: params)
          .and_call_original)

      run_worker
    end
  end

  shared_examples_for 'reschedules the worker' do
    it 'reschedules the worker' do
      expect(described_class).to receive(:perform_in)
        .with(Gitlab::ConditionalConcurrencyLimitControl::DEFAULT_RESCHEDULE_INTERVAL,
          project_id, current_user_id, schedule_id, branch)

      run_worker
    end
  end

  describe '#perform' do
    before do
      allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |instance|
        allow(instance).to receive(:active_scan_execution_policies).and_return([policy])
      end
    end

    subject(:run_worker) { described_class.new.perform(project_id, current_user_id, schedule_id, branch) }

    context 'when project is not found' do
      let(:project_id) { non_existing_record_id }

      it_behaves_like 'does not call RuleScheduleService'
    end

    context 'when user is not found' do
      let(:current_user_id) { non_existing_record_id }

      it_behaves_like 'does not call RuleScheduleService'
    end

    context 'when the user and project exists' do
      it 'delegates the pipeline creation to Security::SecurityOrchestrationPolicies::CreatePipelineService' do
        expect(::Security::SecurityOrchestrationPolicies::CreatePipelineService).to(
          receive(:new)
            .with(project: project, current_user: current_user, params: params)
            .and_call_original)

        run_worker
      end

      context 'when the number of active security policy scheduled scans exceeds the limit' do
        before do
          stub_application_setting(security_policy_scheduled_scans_max_concurrency: 2)
        end

        context 'when the scans are from the same scheduled policy' do
          before do
            create_list(:ci_build, 2,
              :running,
              created_at: 1.minute.ago,
              updated_at: 1.minute.ago,
              pipeline: create(:ci_pipeline, source: :security_orchestration_policy),
              project: project)
          end

          context 'when feature flag `scan_execution_pipeline_concurrency_control` is disabled' do
            before do
              stub_feature_flags(scan_execution_pipeline_concurrency_control: false)
            end

            it_behaves_like 'creates a new pipeline'
          end

          context 'when feature flag `scan_execution_pipeline_concurrency_control` is enabled' do
            it_behaves_like 'does not creates a new pipeline'

            it_behaves_like 'reschedules the worker'
          end

          context 'when the policy is defined at group level' do
            let_it_be(:group) { create(:group) }
            let_it_be(:project) { create(:project, namespace: group) }
            let_it_be(:another_project) { create(:project, namespace: group) }

            context 'when the active scans are from different projects in the group' do
              before do
                create(:ci_build,
                  :running,
                  created_at: 1.minute.ago,
                  updated_at: 1.minute.ago,
                  pipeline: create(:ci_pipeline, source: :security_orchestration_policy),
                  project: project)

                create_list(:ci_build, 2,
                  :running,
                  created_at: 1.minute.ago,
                  updated_at: 1.minute.ago,
                  pipeline: create(:ci_pipeline, source: :security_orchestration_policy),
                  project: another_project)
              end

              context 'when the worker is running for one of the projects in the group ' do
                let(:security_orchestration_policy_configuration) do
                  create(:security_orchestration_policy_configuration, :namespace, namespace: group)
                end

                let(:schedule) do
                  create(:security_orchestration_policy_rule_schedule,
                    security_orchestration_policy_configuration: security_orchestration_policy_configuration)
                end

                it 'does not invokes CreatePipelineService' do
                  [project, another_project].each do |project|
                    expect(::Security::SecurityOrchestrationPolicies::CreatePipelineService).not_to(
                      receive(:new)
                        .with(project: project, current_user: current_user, params: params)
                        .and_call_original)

                    described_class.new.perform(project.id, current_user_id, schedule_id, branch)
                  end
                end

                it_behaves_like 'reschedules the worker'
              end

              context 'when the worker is running for a project outside of the group' do
                let_it_be(:project) { create(:project) }

                context 'when feature flag `scan_execution_pipeline_concurrency_control` is disabled' do
                  before do
                    stub_feature_flags(scan_execution_pipeline_concurrency_control: false)
                  end

                  it_behaves_like 'creates a new pipeline'
                end

                context 'when feature flag `scan_execution_pipeline_concurrency_control` is enabled' do
                  it_behaves_like 'creates a new pipeline'
                end
              end
            end
          end
        end

        context 'when the scans are from the another scheduled policy' do
          before do
            create_list(:ci_build, 2,
              :running,
              created_at: 1.minute.ago,
              updated_at: 1.minute.ago,
              pipeline: create(:ci_pipeline, source: :security_orchestration_policy),
              project: create(:project))
          end

          context 'when feature flag `scan_execution_pipeline_concurrency_control` is disabled' do
            before do
              stub_feature_flags(scan_execution_pipeline_concurrency_control: false)
            end

            it_behaves_like 'creates a new pipeline'
          end

          context 'when feature flag `scan_execution_pipeline_concurrency_control` is enabled' do
            it_behaves_like 'creates a new pipeline'
          end
        end
      end

      context 'when create pipeline service returns errors' do
        before do
          allow_next_instance_of(::Security::SecurityOrchestrationPolicies::CreatePipelineService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'message'))
          end
        end

        it 'logs the error' do
          expect(::Gitlab::AppJsonLogger).to receive(:warn).with({
            'class' => 'Security::ScanExecutionPolicies::CreatePipelineWorker',
            'security_orchestration_policy_configuration_id' => security_orchestration_policy_configuration.id,
            'user_id' => current_user.id,
            'message' => 'message'
          })
          run_worker
        end
      end
    end
  end
end
