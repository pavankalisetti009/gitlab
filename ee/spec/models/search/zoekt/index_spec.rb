# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Index, feature_category: :global_search do
  let_it_be(:namespace) { create(:group) }
  let_it_be_with_reload(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace) }
  let_it_be(:zoekt_node) { create(:zoekt_node) }
  let_it_be(:zoekt_replica) { create(:zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace) }
  let_it_be_with_refind(:zoekt_index) do
    create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace, node: zoekt_node, replica: zoekt_replica,
      reserved_storage_bytes: 100.megabytes)
  end

  subject { zoekt_index }

  describe 'relations' do
    it { is_expected.to belong_to(:zoekt_enabled_namespace).inverse_of(:indices) }
    it { is_expected.to belong_to(:node).inverse_of(:indices) }
    it { is_expected.to belong_to(:replica).inverse_of(:indices) }
    it { is_expected.to have_many(:zoekt_repositories).inverse_of(:zoekt_index) }

    it 'restricts deletion when there are associated zoekt repositories' do
      project = create(:project, namespace_id: zoekt_index.namespace_id)
      repo = zoekt_index.zoekt_repositories.create!(project: project, state: :pending)

      expect(zoekt_index.zoekt_repositories).to match_array([repo])
      expect { zoekt_index.destroy! }.to raise_error ActiveRecord::InvalidForeignKey

      repo.destroy!

      expect { zoekt_index.destroy! }.not_to raise_error
    end
  end

  it { expect(described_class.new.reserved_storage_bytes).to eq 10.gigabytes }

  describe 'validations' do
    it 'validates that zoekt_enabled_namespace root_namespace_id matches namespace_id' do
      zoekt_index = described_class.new(zoekt_enabled_namespace: zoekt_enabled_namespace,
        node: zoekt_node, namespace_id: 0)
      expect(zoekt_index).to be_invalid
    end

    it { expect(described_class).to validate_jsonb_schema(['zoekt_indices_metadata']) }
  end

  describe 'callbacks' do
    describe '#destroy!' do
      it 'calls Search::Zoekt::NamespaceIndexerWorker for the namespace with delete operation' do
        expect(Search::Zoekt::NamespaceIndexerWorker).to receive(:perform_async)
          .with(zoekt_enabled_namespace.root_namespace_id, 'delete', zoekt_node.id)

        zoekt_index.destroy!
      end
    end
  end

  describe 'scopes' do
    let_it_be(:namespace_2) { create(:group) }
    let_it_be_with_reload(:zoekt_enabled_namespace_2) { create(:zoekt_enabled_namespace, namespace: namespace_2) }
    let_it_be(:node_2) { create(:zoekt_node) }
    let_it_be(:zoekt_index_2) do
      create(:zoekt_index, node: node_2, zoekt_enabled_namespace: zoekt_enabled_namespace_2)
    end

    before do
      create_list(:zoekt_repository, 5, zoekt_index: zoekt_index, size_bytes: 100.megabytes)
    end

    describe '.for_node' do
      subject { described_class.for_node(node_2) }

      it { is_expected.to contain_exactly(zoekt_index_2) }
    end

    describe '.for_root_namespace_id' do
      subject { described_class.for_root_namespace_id(namespace_2) }

      it { is_expected.to contain_exactly(zoekt_index_2) }

      context 'when there are orphaned indices' do
        before do
          zoekt_index_2.update!(zoekt_enabled_namespace: nil)
        end

        it { is_expected.to be_empty }
      end
    end

    describe '.for_root_namespace_id_with_search_enabled' do
      it 'correctly filters on the search field' do
        expect(described_class.for_root_namespace_id_with_search_enabled(namespace_2))
          .to contain_exactly(zoekt_index_2)

        zoekt_enabled_namespace_2.update!(search: false)

        expect(described_class.for_root_namespace_id_with_search_enabled(namespace_2))
          .to be_empty
      end
    end

    describe '.with_all_repositories_ready' do
      let_it_be(:idx) { create(:zoekt_index) } # It has some pending zoekt_repositories
      let_it_be(:idx2) { create(:zoekt_index) } # It has all ready zoekt_repositories
      let_it_be(:idx3) { create(:zoekt_index) } # It does not have zoekt_repositories
      let_it_be(:idx_project) { create(:project, namespace_id: idx.namespace_id) }
      let_it_be(:idx_project2) { create(:project, namespace_id: idx.namespace_id) }
      let_it_be(:idx2_project2) { create(:project, namespace_id: idx2.namespace_id) }

      before do
        idx.zoekt_repositories.create!(zoekt_index: idx, project: idx_project, state: :pending)
        idx.zoekt_repositories.create!(zoekt_index: idx, project: idx_project2, state: :ready)
        idx2.zoekt_repositories.create!(zoekt_index: idx2, project: idx2_project2, state: :ready)
      end

      it 'returns all the indices whose all zoekt_repositories are ready' do
        expect(described_class.with_all_repositories_ready).to contain_exactly(idx2)
      end
    end

    describe '.searchable' do
      let_it_be(:zoekt_index_ready) do
        create(:zoekt_index, node: zoekt_node, zoekt_enabled_namespace: zoekt_enabled_namespace_2, state: :ready)
      end

      it 'returns correct indices' do
        expect(described_class.searchable).to contain_exactly(zoekt_index_ready)
      end
    end

    describe '.preload_zoekt_enabled_namespace_and_namespace' do
      it 'preloads the project and avoids N+1 queries' do
        index = described_class.preload_zoekt_enabled_namespace_and_namespace.first
        recorder = ActiveRecord::QueryRecorder.new { index.zoekt_enabled_namespace.namespace }
        expect(recorder.count).to be_zero
      end
    end

    describe '.preload_node' do
      it 'preloads the node and avoids N+1 queries' do
        index = described_class.preload_node.first
        recorder = ActiveRecord::QueryRecorder.new { index.node }
        expect(recorder.count).to be_zero
      end
    end

    describe '.should_be_marked_as_orphaned' do
      let_it_be(:idx) { create(:zoekt_index) }
      let_it_be(:idx_missing_replica) { create(:zoekt_index) }
      let_it_be(:idx_missing_enabled_namespace) { create(:zoekt_index) }
      let_it_be(:idx_already_marked_as_orphaned) { create(:zoekt_index) }
      let_it_be(:zoekt_replica) { create(:zoekt_replica) }

      it 'returns indices that are missing either an enabled namespace or a replica' do
        idx_missing_replica.replica.destroy!
        idx_missing_enabled_namespace.zoekt_enabled_namespace.destroy!
        idx_already_marked_as_orphaned.replica.destroy!
        idx_already_marked_as_orphaned.orphaned!

        expect(described_class.should_be_marked_as_orphaned).to match_array([idx_missing_replica,
          idx_missing_enabled_namespace])
      end
    end

    describe '.should_be_deleted' do
      let_it_be(:idx) { create(:zoekt_index) }
      let_it_be(:idx_orphaned) { create(:zoekt_index, state: :orphaned) }
      let_it_be(:idx_pending_deletion) { create(:zoekt_index, state: :pending_deletion) }

      it 'returns indices that are marked as either orphaned or pending_deletion' do
        expect(described_class.should_be_deleted).to match_array([idx_orphaned, idx_pending_deletion])
      end
    end

    describe '.should_have_overprovisioned_watermark' do
      it 'returns indices that have too much storage' do
        zoekt_index.update!(reserved_storage_bytes: 100_000_000, state: :ready)
        expect(described_class.should_have_overprovisioned_watermark).to match_array(zoekt_index)

        zoekt_index.update!(reserved_storage_bytes: 0)
        expect(described_class.should_have_overprovisioned_watermark).to be_empty
      end

      it 'does not returns indices that already have overprovisioned watermark level' do
        zoekt_index.update!(reserved_storage_bytes: 100_000_000, watermark_level: :overprovisioned, state: :ready)
        expect(described_class.should_have_overprovisioned_watermark).to be_empty
      end
    end

    describe '.should_have_low_watermark' do
      it 'returns indices that have over low watermark of storage' do
        saturated_storage = zoekt_index.reserved_storage_bytes * Search::Zoekt::Index::STORAGE_LOW_WATERMARK

        zoekt_index.update!(used_storage_bytes: saturated_storage)
        expect(described_class.should_have_low_watermark).to match_array(zoekt_index)

        zoekt_index.update!(reserved_storage_bytes: zoekt_index.used_storage_bytes * 2)
        expect(described_class.should_have_low_watermark).to be_empty
      end

      it 'does not return indices that already have low watermarked state' do
        saturated_storage = zoekt_index.reserved_storage_bytes * Search::Zoekt::Index::STORAGE_LOW_WATERMARK

        zoekt_index.update!(used_storage_bytes: saturated_storage, watermark_level: :low_watermark_exceeded)
        expect(described_class.should_have_low_watermark).to be_empty
      end

      it 'returns indices that have high watermark state but storage that reflects low watermark' do
        saturated_storage = zoekt_index.reserved_storage_bytes * Search::Zoekt::Index::STORAGE_LOW_WATERMARK

        zoekt_index.update!(used_storage_bytes: saturated_storage, watermark_level: :high_watermark_exceeded)
        expect(described_class.should_have_low_watermark).to match_array(zoekt_index)
      end
    end

    describe '.should_have_high_watermark' do
      it 'returns indices that have over high watermark of storage' do
        saturated_storage = zoekt_index.reserved_storage_bytes * Search::Zoekt::Index::STORAGE_HIGH_WATERMARK

        zoekt_index.update!(used_storage_bytes: saturated_storage)
        expect(described_class.should_have_high_watermark).to match_array(zoekt_index)

        zoekt_index.update!(reserved_storage_bytes: zoekt_index.used_storage_bytes * 2)
        expect(described_class.should_have_high_watermark).to be_empty
      end

      it 'does not return indices that already have high watermark state' do
        saturated_storage = zoekt_index.reserved_storage_bytes * Search::Zoekt::Index::STORAGE_HIGH_WATERMARK

        zoekt_index.update!(used_storage_bytes: saturated_storage, watermark_level: :high_watermark_exceeded)
        expect(described_class.should_have_high_watermark).to be_empty
      end
    end

    describe '.with_storage_over_percent' do
      it 'returns indices over percent' do
        zoekt_index.update!(used_storage_bytes: 10.megabytes)
        expect(described_class.with_storage_over_percent(0.1).pluck_primary_key).to match_array([zoekt_index.id])
        expect(described_class.with_storage_over_percent(0.2).pluck_primary_key).to be_empty
      end

      it 'does not return zoekt indices with nothing reserved' do
        zoekt_index.update!(used_storage_bytes: 100.megabytes, reserved_storage_bytes: 0)
        expect(described_class.with_storage_over_percent(0.01).pluck_primary_key).to be_empty

        zoekt_index.update!(used_storage_bytes: 100.megabytes, reserved_storage_bytes: nil)
        expect(described_class.with_storage_over_percent(0.01).pluck_primary_key).to be_empty
      end
    end

    describe '.with_reserved_storage_bytes' do
      it 'returns indices with reserved storage' do
        expect(described_class.with_reserved_storage_bytes.pluck_primary_key).to match_array([zoekt_index.id])

        zoekt_index.update!(reserved_storage_bytes: 0)
        expect(described_class.with_reserved_storage_bytes.pluck_primary_key).to be_empty

        zoekt_index.update!(reserved_storage_bytes: nil)
        expect(described_class.with_reserved_storage_bytes.pluck_primary_key).to be_empty
      end
    end
  end

  describe '#update_reserved_storage_bytes!' do
    let_it_be(:zoekt_node) { create(:zoekt_node, total_bytes: 100_000) }
    let_it_be(:idx) do
      create(:zoekt_index, used_storage_bytes: 90, reserved_storage_bytes: 100, node: zoekt_node)
    end

    it 'updates indices with the sum of size_bytes for all associated repositories' do
      ideal_reserved_storage = idx.used_storage_bytes / described_class::STORAGE_IDEAL_PERCENT_USED

      expect do
        idx.update_reserved_storage_bytes!
      end.to change {
        idx.reload.reserved_storage_bytes
      }.from(100).to(ideal_reserved_storage)

      expect(
        idx.used_storage_bytes / idx.reserved_storage_bytes.to_f
      ).to eq(described_class::STORAGE_IDEAL_PERCENT_USED)
    end

    describe 'updates the watermark level to the appropriate state' do
      let(:percent_used) { 0 }

      before do
        idx.high_watermark_exceeded!
        allow(idx).to receive(:storage_percent_used).and_return(percent_used)
      end

      context 'when index should be marked as overprovisioned' do
        let(:percent_used) { 0.01 }

        it 'updates the watermark level to the appropriate state' do
          expect { idx.update_reserved_storage_bytes! }.to change {
            idx.reload.watermark_level
          }.from("high_watermark_exceeded").to("overprovisioned")
        end
      end

      context 'when index should be marked as healthy' do
        let(:percent_used) { described_class::STORAGE_IDEAL_PERCENT_USED }

        it 'updates the watermark level to the appropriate state' do
          expect { idx.update_reserved_storage_bytes! }.to change {
            idx.reload.watermark_level
          }.from("high_watermark_exceeded").to("healthy")
        end
      end

      context 'when index should be marked as low_watermark_exceeded' do
        let(:percent_used) { described_class::STORAGE_LOW_WATERMARK }

        it 'updates the watermark level to the appropriate state' do
          expect { idx.update_reserved_storage_bytes! }.to change {
            idx.reload.watermark_level
          }.from("high_watermark_exceeded").to("low_watermark_exceeded")
        end
      end

      context 'when index should be marked as high_watermark_exceeded' do
        let(:percent_used) { described_class::STORAGE_HIGH_WATERMARK }

        it 'updates the watermark level to the appropriate state' do
          idx.low_watermark_exceeded!

          expect { idx.update_reserved_storage_bytes! }.to change {
            idx.reload.watermark_level
          }.from("low_watermark_exceeded").to("high_watermark_exceeded")
        end
      end
    end

    context 'when the node only has a little bit more storage' do
      let_it_be(:zoekt_node) { create(:zoekt_node, total_bytes: 102, used_bytes: 0) }

      let_it_be(:idx) do
        create(:zoekt_index, used_storage_bytes: 90, reserved_storage_bytes: 100, node: zoekt_node)
      end

      it 'increases the node reservation as much as possible' do
        expect do
          idx.update_reserved_storage_bytes!
        end.to change {
          idx.reload.reserved_storage_bytes
        }.from(100).to(102)
      end
    end

    context 'when the node does not have any more storage' do
      let_it_be(:zoekt_node) { create(:zoekt_node, total_bytes: 100, used_bytes: 0) }

      let_it_be(:idx) do
        create(:zoekt_index, used_storage_bytes: 90, reserved_storage_bytes: 100, node: zoekt_node)
      end

      it 'does not do anything' do
        expect do
          idx.update_reserved_storage_bytes!
        end.not_to change {
          idx.reload.reserved_storage_bytes
        }
      end
    end

    context 'when an exception occurs' do
      it 'logs the error and re-raises the exception' do
        stubbed_logger = instance_double(::Search::Zoekt::Logger)
        expect(::Search::Zoekt::Logger).to receive(:build).and_return stubbed_logger

        expected_error_message = 'Ka-Boom'

        expect(stubbed_logger).to receive(:error).with({
          class: 'Search::Zoekt::Index',
          message: 'Error attempting to update reserved_storage_bytes',
          error: expected_error_message,
          new_reserved_bytes: anything,
          reserved_storage_bytes: anything,
          index_id: idx.id
        }.with_indifferent_access)

        expect(idx).to receive(:used_storage_bytes).and_raise expected_error_message

        expect { idx.update_reserved_storage_bytes! }.to raise_error expected_error_message
      end
    end
  end

  describe '#free_storage_bytes' do
    it 'is difference between reserved bytes and used bytes' do
      allow(zoekt_index).to receive(:reserved_storage_bytes).and_return(100)
      allow(zoekt_index).to receive(:used_storage_bytes).and_return(1)
      expect(zoekt_index.free_storage_bytes).to eq(99)
    end
  end

  describe '#should_be_deleted?' do
    it 'returns true if the index state is orphaned or pending_deletion' do
      expect(zoekt_index).not_to be_should_be_deleted

      zoekt_index.state = :orphaned
      expect(zoekt_index).to be_should_be_deleted

      zoekt_index.state = :pending_deletion
      expect(zoekt_index).to be_should_be_deleted

      zoekt_index.state = :ready
      expect(zoekt_index).not_to be_should_be_deleted
    end
  end
end
