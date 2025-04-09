# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ProjectComplianceStatusesRemovalWorker, feature_category: :compliance_management do
  let(:worker) { described_class.new }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:framework) { create(:compliance_framework, namespace: group) }

  describe '#perform' do
    subject(:perform) { worker.perform(project.id, framework.id) }

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [project.id, framework.id] }
    end

    it 'has the `until_executed` deduplicate strategy' do
      expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
    end

    shared_examples 'returns early without processing' do
      it 'does nothing' do
        expect(ComplianceManagement::ComplianceFramework::ProjectRequirementStatuses::BulkDestroyService)
          .not_to receive(:new)

        perform
      end
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(enable_stale_compliance_status_removal: false)
      end

      it_behaves_like 'returns early without processing'
    end

    context 'when given valid parameters' do
      context 'when framework is applied to the project' do
        before do
          create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework)
        end

        it_behaves_like 'returns early without processing'

        context 'when skip_framework_check is true' do
          subject(:perform) { worker.perform(project.id, framework.id, { skip_framework_check: true }) }

          it 'calls BulkDestroyService to remove statuses' do
            expect(ComplianceManagement::ComplianceFramework::ProjectRequirementStatuses::BulkDestroyService)
              .to receive(:new).with(project.id, framework.id)

            perform
          end
        end
      end

      context 'when framework is not applied to the project' do
        it 'calls BulkDestroyService to remove statuses' do
          expect(ComplianceManagement::ComplianceFramework::ProjectRequirementStatuses::BulkDestroyService)
            .to receive(:new).with(project.id, framework.id)

          perform
        end

        context 'when an error is raised' do
          let(:error) { StandardError.new('Test error') }

          before do
            allow(ComplianceManagement::ComplianceFramework::ProjectSettings)
              .to receive(:by_framework_and_project).and_raise(error)
            allow(Gitlab::ErrorTracking).to receive(:log_exception)
          end

          it 'logs the exception' do
            expect(Gitlab::ErrorTracking).to receive(:log_exception).with(
              error,
              framework_id: framework.id,
              project_id: project.id
            ).once

            perform
          end
        end
      end
    end

    context 'when given invalid parameters' do
      subject(:perform) { worker.perform(project.id, nil) }

      it_behaves_like 'returns early without processing'
    end
  end
end
