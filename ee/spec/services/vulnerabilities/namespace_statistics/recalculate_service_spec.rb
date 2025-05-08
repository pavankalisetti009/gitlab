# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceStatistics::RecalculateService, feature_category: :security_asset_inventories do
  describe '.execute' do
    it 'instantiates a new service object and calls execute' do
      expect_next_instance_of(described_class, :project_id, :group, false) do |instance|
        expect(instance).to receive(:execute)
      end

      described_class.execute(:project_id, :group)
    end

    it 'passes deleted_project parameter correctly' do
      expect_next_instance_of(described_class, :project_id, :group, true) do |instance|
        expect(instance).to receive(:execute)
      end

      described_class.execute(:project_id, :group, deleted_project: true)
    end
  end

  describe '#execute' do
    let_it_be(:parent_group) { create(:group) }
    let_it_be(:child_group) { create(:group, parent: parent_group) }
    let_it_be(:project) { create(:project, group: child_group) }
    let_it_be(:project_id) { project.id }

    context 'when both project_id and group are present' do
      subject(:remove_project_update) do
        described_class.new(project_id, child_group, deleted_project).execute
      end

      context 'when deleted_project is false' do
        let(:deleted_project) { false }
        let(:adjustment_service) { instance_double(Vulnerabilities::NamespaceStatistics::AdjustmentService) }
        let(:update_service) { class_double(Vulnerabilities::NamespaceStatistics::UpdateService) }
        let(:namespace_diffs) do
          [{ 'namespace_id' => child_group.id, 'traversal_ids' => "{#{parent_group.id},#{child_group.id}}" }]
        end

        before do
          allow(Vulnerabilities::NamespaceStatistics::AdjustmentService).to receive(:new)
            .with([child_group.id]).and_return(adjustment_service)
          allow(adjustment_service).to receive(:execute).and_return(namespace_diffs)
          allow(Vulnerabilities::NamespaceStatistics::UpdateService).to receive(:execute)
        end

        it 'recalculates group statistics and propagates changes to ancestors' do
          expected_ancestor_diff = {
            'namespace_id' => parent_group.id,
            'traversal_ids' => "{#{parent_group.id}}"
          }

          expect(Vulnerabilities::NamespaceStatistics::AdjustmentService).to receive(:new)
            .with([child_group.id]).and_return(adjustment_service)
          expect(adjustment_service).to receive(:execute).and_return(namespace_diffs)
          expect(Vulnerabilities::NamespaceStatistics::UpdateService).to receive(:execute)
            .with([expected_ancestor_diff])

          remove_project_update
        end
      end

      context 'when deleted_project is true' do
        let(:deleted_project) { true }
        let(:statistic_relation) { instance_double(ActiveRecord::Relation) }
        let(:adjustment_service) { instance_double(Vulnerabilities::NamespaceStatistics::AdjustmentService) }
        let(:update_service) { class_double(Vulnerabilities::NamespaceStatistics::UpdateService) }
        let(:namespace_diffs) do
          [{ 'namespace_id' => child_group.id, 'traversal_ids' => "{#{parent_group.id},#{child_group.id}}" }]
        end

        before do
          allow(Vulnerabilities::Statistic).to receive(:by_projects).with(project_id).and_return(statistic_relation)
          allow(statistic_relation).to receive(:delete_all)
          allow(Vulnerabilities::NamespaceStatistics::AdjustmentService).to receive(:new)
            .with([child_group.id]).and_return(adjustment_service)
          allow(adjustment_service).to receive(:execute).and_return(namespace_diffs)
          allow(Vulnerabilities::NamespaceStatistics::UpdateService).to receive(:execute)
        end

        it 'verifies no project related records exist before recalculating' do
          expect(Vulnerabilities::Statistic).to receive(:by_projects).with(project_id).and_return(statistic_relation)
          expect(statistic_relation).to receive(:delete_all)

          remove_project_update
        end

        it 'recalculates group statistics and propagates changes to ancestors' do
          expected_ancestor_diff = {
            'namespace_id' => parent_group.id,
            'traversal_ids' => "{#{parent_group.id}}"
          }

          expect(Vulnerabilities::Statistic).to receive(:by_projects)
            .with(project_id).and_return(statistic_relation)
          expect(statistic_relation).to receive(:delete_all)
          expect(Vulnerabilities::NamespaceStatistics::AdjustmentService).to receive(:new)
            .with([child_group.id]).and_return(adjustment_service)
          expect(adjustment_service).to receive(:execute).and_return(namespace_diffs)
          expect(Vulnerabilities::NamespaceStatistics::UpdateService).to receive(:execute)
            .with([expected_ancestor_diff])

          remove_project_update
        end
      end
    end

    context 'when project_id is missing' do
      subject(:remove_project_update) do
        described_class.new(nil, child_group, false).execute
      end

      it 'returns early without executing update logic' do
        expect(Vulnerabilities::NamespaceStatistics::AdjustmentService).not_to receive(:new)

        expect(remove_project_update).to be_nil
      end
    end

    context 'when group is missing' do
      subject(:remove_project_update) do
        described_class.new(project_id, nil, false).execute
      end

      it 'returns early without executing update logic' do
        expect(Vulnerabilities::NamespaceStatistics::AdjustmentService).not_to receive(:new)

        expect(remove_project_update).to be_nil
      end
    end

    context 'when namespace_diffs is empty' do
      subject(:remove_project_update) do
        described_class.new(project_id, child_group, false).execute
      end

      let(:adjustment_service) { instance_double(Vulnerabilities::NamespaceStatistics::AdjustmentService) }

      before do
        allow(Vulnerabilities::NamespaceStatistics::AdjustmentService).to receive(:new)
          .with([child_group.id]).and_return(adjustment_service)
        allow(adjustment_service).to receive(:execute).and_return([])
      end

      it 'does not call UpdateService' do
        expect(Vulnerabilities::NamespaceStatistics::UpdateService).not_to receive(:execute)

        remove_project_update
      end
    end

    context 'when namespace_diffs has more than one entry' do
      subject(:remove_project_update) do
        described_class.new(project_id, child_group, false).execute
      end

      let(:adjustment_service) { instance_double(Vulnerabilities::NamespaceStatistics::AdjustmentService) }
      let(:namespace_diffs) { [{ 'namespace_id' => 1 }, { 'namespace_id' => 2 }] }

      before do
        allow(Vulnerabilities::NamespaceStatistics::AdjustmentService).to receive(:new)
          .with([child_group.id]).and_return(adjustment_service)
        allow(adjustment_service).to receive(:execute).and_return(namespace_diffs)
      end

      it 'does not call UpdateService' do
        expect(Vulnerabilities::NamespaceStatistics::UpdateService).not_to receive(:execute)

        remove_project_update
      end
    end

    context 'when traversal_ids array has only one element' do
      subject(:remove_project_update) do
        described_class.new(project_id, child_group, false).execute
      end

      let(:adjustment_service) { instance_double(Vulnerabilities::NamespaceStatistics::AdjustmentService) }
      let(:namespace_diffs) { [{ 'namespace_id' => child_group.id, 'traversal_ids' => "{#{child_group.id}}" }] }

      before do
        allow(Vulnerabilities::NamespaceStatistics::AdjustmentService).to receive(:new)
          .with([child_group.id]).and_return(adjustment_service)
        allow(adjustment_service).to receive(:execute).and_return(namespace_diffs)
      end

      it 'does not call UpdateService' do
        expect(Vulnerabilities::NamespaceStatistics::UpdateService).not_to receive(:execute)

        remove_project_update
      end
    end
  end
end
