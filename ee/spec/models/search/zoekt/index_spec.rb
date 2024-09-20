# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Index, feature_category: :global_search do
  let_it_be(:namespace) { create(:group) }
  let_it_be_with_reload(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace) }
  let_it_be(:zoekt_node) { create(:zoekt_node) }
  let_it_be(:zoekt_replica) { create(:zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace) }
  let_it_be(:zoekt_index) do
    create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace, node: zoekt_node, replica: zoekt_replica)
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
  end

  describe 'callbacks' do
    let_it_be(:namespace_2) { create(:group) }
    let_it_be(:another_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace_2) }

    describe '#create!' do
      context 'when feature flag zoekt_initial_indexing_task is disabled' do
        before do
          stub_feature_flags(zoekt_initial_indexing_task: false)
        end

        it 'triggers indexing for the namespace' do
          expect(::Search::Zoekt::NamespaceIndexerWorker).to receive(:perform_async)
            .with(another_enabled_namespace.root_namespace_id, :index)

          another_replica = create(:zoekt_replica, zoekt_enabled_namespace: another_enabled_namespace)

          described_class.create!(zoekt_enabled_namespace: another_enabled_namespace, node: zoekt_node,
            namespace_id: another_enabled_namespace.root_namespace_id, replica: another_replica)
        end
      end

      it 'does not triggers indexing for the namespace' do
        expect(::Search::Zoekt::NamespaceIndexerWorker).not_to receive(:perform_async)
          .with(another_enabled_namespace.root_namespace_id, :index)

        another_replica = create(:zoekt_replica, zoekt_enabled_namespace: another_enabled_namespace)

        described_class.create!(zoekt_enabled_namespace: another_enabled_namespace, node: zoekt_node,
          namespace_id: another_enabled_namespace.root_namespace_id, replica: another_replica)
      end
    end

    describe '#destroy!' do
      it 'removes index for the namespace' do
        another_zoekt_index = create(:zoekt_index, zoekt_enabled_namespace: another_enabled_namespace,
          namespace_id: another_enabled_namespace.root_namespace_id)

        expect(::Search::Zoekt::NamespaceIndexerWorker).to receive(:perform_async)
          .with(another_enabled_namespace.root_namespace_id, :delete, another_zoekt_index.zoekt_node_id)

        another_zoekt_index.destroy!
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

    describe '#for_node' do
      subject { described_class.for_node(node_2) }

      it { is_expected.to contain_exactly(zoekt_index_2) }
    end

    describe '#for_root_namespace_id' do
      subject { described_class.for_root_namespace_id(namespace_2) }

      it { is_expected.to contain_exactly(zoekt_index_2) }

      context 'when there are orphaned indices' do
        before do
          zoekt_index_2.update!(zoekt_enabled_namespace: nil)
        end

        it { is_expected.to be_empty }
      end
    end

    describe '#for_root_namespace_id_with_search_enabled' do
      it 'correctly filters on the search field' do
        expect(described_class.for_root_namespace_id_with_search_enabled(namespace_2))
          .to contain_exactly(zoekt_index_2)

        zoekt_enabled_namespace_2.update!(search: false)

        expect(described_class.for_root_namespace_id_with_search_enabled(namespace_2))
          .to be_empty
      end
    end

    describe '#with_all_repositories_ready' do
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

    describe '#searchable' do
      let_it_be(:zoekt_index_ready) do
        create(:zoekt_index, node: zoekt_node, zoekt_enabled_namespace: zoekt_enabled_namespace_2, state: :ready)
      end

      it 'returns correct indices' do
        expect(described_class.searchable).to contain_exactly(zoekt_index_ready)
      end
    end

    describe '#preload_zoekt_enabled_namespace_and_namespace' do
      it 'preloads the project and avoids N+1 queries' do
        index = described_class.preload_zoekt_enabled_namespace_and_namespace.first
        recorder = ActiveRecord::QueryRecorder.new { index.zoekt_enabled_namespace.namespace }
        expect(recorder.count).to be_zero
      end
    end

    describe '#preload_node' do
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
  end

  describe '#used_storage_bytes' do
    let_it_be(:size_bytes) { 100.megabytes }
    let_it_be(:repos) { create_list(:zoekt_repository, 5, zoekt_index: zoekt_index, size_bytes: size_bytes) }

    it 'returns the sum of size_bytes for all repository associated with this index' do
      expect(zoekt_index.used_storage_bytes).to eq(repos.length * size_bytes)
    end
  end

  describe '#free_storage_bytes' do
    it 'is difference between reserved bytes and used bytes' do
      allow(zoekt_index).to receive(:reserved_storage_bytes).and_return(100)
      allow(zoekt_index).to receive(:used_storage_bytes).and_return(1)
      expect(zoekt_index.free_storage_bytes).to eq(99)
    end
  end
end
