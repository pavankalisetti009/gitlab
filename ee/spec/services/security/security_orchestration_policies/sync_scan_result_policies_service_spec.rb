# frozen_string_literal: true

require "spec_helper"

RSpec.describe Security::SecurityOrchestrationPolicies::SyncScanResultPoliciesService, feature_category: :security_policy_management do
  let_it_be(:configuration, refind: true) { create(:security_orchestration_policy_configuration, configured_at: nil) }

  let(:service) { described_class.new(configuration) }

  describe '#execute' do
    subject { service.execute }

    context 'with delay' do
      let_it_be(:project1) { create(:project) }
      let_it_be(:project2) { create(:project) }
      let_it_be(:project3) { create(:project) }

      let(:sync_project_service) do
        instance_double(Security::SecurityOrchestrationPolicies::SyncScanResultPoliciesProjectService)
      end

      let(:projects) { [project1, project2, project3] }

      before do
        allow(Security::SecurityOrchestrationPolicies::SyncScanResultPoliciesProjectService).to receive(:new)
          .and_return(sync_project_service)
        allow(service).to receive(:projects).and_return(projects)
      end

      it 'increases delay by 1 minute for each batch' do
        allow(projects).to receive(:each_batch).and_yield(projects[0..1]).and_yield([projects[2]])

        expect(sync_project_service).to receive(:execute).with(project1.id, { delay: 0.seconds })
        expect(sync_project_service).to receive(:execute).with(project2.id, { delay: 0.seconds })
        expect(sync_project_service).to receive(:execute).with(project3.id, { delay: 10.seconds })

        service.execute
      end
    end

    it 'triggers worker for the configuration' do
      expect_next_instance_of(
        Security::SecurityOrchestrationPolicies::SyncScanResultPoliciesProjectService,
        configuration
      ) do |sync_service|
        expect(sync_service).to receive(:execute).with(configuration.project_id, { delay: 0 })
      end

      subject
    end

    context 'with namespace association' do
      let_it_be(:namespace) { create(:namespace) }
      let_it_be(:project) { create(:project, namespace: namespace) }
      let_it_be(:configuration, refind: true) do
        create(:security_orchestration_policy_configuration, configured_at: nil, project: nil, namespace: namespace)
      end

      it 'triggers SyncScanResultPoliciesProjectService for the configuration and project_id' do
        expect_next_instance_of(
          Security::SecurityOrchestrationPolicies::SyncScanResultPoliciesProjectService,
          configuration
        ) do |sync_service|
          expect(sync_service).to receive(:execute).with(project.id, { delay: 0 })
        end

        subject
      end

      context 'with multiple projects in the namespace' do
        let_it_be(:worker) { Security::ProcessScanResultPolicyWorker }

        it 'does trigger SyncScanResultPoliciesProjectService for each project in group' do
          create_list(:project, 2, namespace: namespace)

          expect(worker).to receive(:perform_in).and_call_original.exactly(3).times

          subject
        end
      end
    end
  end
end
