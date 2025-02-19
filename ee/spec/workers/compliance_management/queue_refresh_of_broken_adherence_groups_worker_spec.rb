# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::QueueRefreshOfBrokenAdherenceGroupsWorker,
  feature_category: :compliance_management do
  let_it_be(:good_group) { create :group }
  let_it_be(:old_group) { create :group }
  let_it_be(:project) { create :project, namespace: good_group }
  let_it_be(:project_compliance_standards_adherence) { ::Projects::ComplianceStandards::Adherence }
  let_it_be(:good_adherence) do
    project_compliance_standards_adherence.create! created_at: '2023-08-15 00:00:00',
      updated_at: '2023-08-15 00:00:00',
      project_id: project.id,
      namespace_id: good_group.id,
      status: 0,
      check_name: 0,
      standard: 0
  end

  let_it_be(:broken_adherence) do
    project_compliance_standards_adherence.create! created_at: '2023-08-15 00:00:00',
      updated_at: '2023-08-15 00:00:00',
      project_id: project.id,
      namespace_id: old_group.id,
      status: 0,
      check_name: 1,
      standard: 1
  end

  subject(:worker) { described_class.new }

  describe '#perform' do
    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(ff_compliance_repair_adherences: false)
      end

      it 'does not queue any jobs' do
        expect(ComplianceManagement::Standards::RefreshWorker).not_to receive(:perform_async)

        worker.perform
      end
    end

    context 'when feature flag is enabled(default in tests)' do
      it 'queues refresh jobs for groups with broken adherences' do
        expect(ComplianceManagement::Standards::RefreshWorker)
          .to receive(:perform_async).with(hash_including({ 'group_id' => good_group.id }))
        expect(worker)
          .to receive(:log_extra_metadata_on_done).with(:group_id, good_group.id)

        worker.perform
      end
    end

    context 'when the worker is running for more than 4 minutes' do
      before do
        allow(Gitlab::Metrics::System).to receive(:monotonic_time).and_return(0, 241)
      end

      it 'worker logs timeout and quits' do
        expect(worker)
          .to receive(:log_extra_metadata_on_done).with(:timeout_reached, 241)

        worker.perform
      end
    end
  end
end
