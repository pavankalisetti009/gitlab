# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::Node, feature_category: :global_search do
  let_it_be(:indexed_namespace1) { create(:namespace) }
  let_it_be(:indexed_namespace2) { create(:namespace) }
  let_it_be(:unindexed_namespace) { create(:namespace) }
  let_it_be_with_reload(:node) do
    create(:zoekt_node, index_base_url: 'http://example.com:1234/', search_base_url: 'http://example.com:4567/')
  end

  before do
    enabled_namespace1 = create(:zoekt_enabled_namespace, namespace: indexed_namespace1)
    create(:zoekt_index, :ready, node: node, zoekt_enabled_namespace: enabled_namespace1)
    enabled_namespace2 = create(:zoekt_enabled_namespace, namespace: indexed_namespace2)
    create(:zoekt_index, :ready, node: node, zoekt_enabled_namespace: enabled_namespace2)
  end

  describe 'relations' do
    it { is_expected.to have_many(:indices).inverse_of(:node) }
    it { is_expected.to have_many(:tasks).inverse_of(:node) }
    it { is_expected.to have_many(:enabled_namespaces).through(:indices) }
  end

  describe 'scopes' do
    describe '.online' do
      let_it_be(:online_node) { create(:zoekt_node, last_seen_at: 1.second.ago) }
      let_it_be(:offline_node) { create(:zoekt_node, last_seen_at: 10.minutes.ago) }

      it 'returns nodes considered to be online' do
        expect(described_class.online).to contain_exactly(node, online_node)
      end
    end

    describe '.by_name' do
      let_it_be(:node1) { create(:zoekt_node, metadata: { name: 'node1' }) }
      let_it_be(:node2) { create(:zoekt_node, metadata: { name: 'node2' }) }
      let_it_be(:node3) { create(:zoekt_node, metadata: { name: 'node3' }) }

      it 'returns nodes filtered by name' do
        expect(described_class.by_name('node1')).to contain_exactly(node1)
        expect(described_class.by_name('node1', 'node2')).to contain_exactly(node1, node2)
        expect(described_class.by_name('non_existent')).to be_empty
      end
    end
  end

  describe 'validations' do
    describe 'metadata' do
      it { expect(described_class).to validate_jsonb_schema(['zoekt_node_metadata']) }
    end
  end

  describe '.find_or_initialize_by_task_request', :freeze_time do
    let(:base_params) do
      {
        'uuid' => '3869fe21-36d1-4612-9676-0b783ef2dcd7',
        'node.name' => 'm1.local',
        'node.url' => 'http://localhost:6080',
        'disk.all' => 994662584320,
        'disk.free' => 461988872192,
        'disk.used' => 532673712128,
        'node.task_count' => 5,
        'node.concurrency' => 10
      }
    end

    subject(:tasked_node) { described_class.find_or_initialize_by_task_request(params) }

    context 'when node.search_url is unset' do
      let(:params) { base_params }

      it 'returns a new record with correct base_urls' do
        expect(tasked_node).not_to be_persisted
        expect(tasked_node.index_base_url).to eq(params['node.url'])
        expect(tasked_node.search_base_url).to eq(params['node.url'])
      end
    end

    context 'when node.search_url is set' do
      let(:params) { base_params.merge('node.search_url' => 'http://localhost:6090') }

      context 'when node does not exist for given UUID' do
        it 'returns a new record with correct attributes' do
          expect(tasked_node).not_to be_persisted
          expect(tasked_node.index_base_url).to eq(params['node.url'])
          expect(tasked_node.search_base_url).to eq(params['node.search_url'])
          expect(tasked_node.uuid).to eq(params['uuid'])
          expect(tasked_node.last_seen_at).to eq(Time.zone.now)
          expect(tasked_node.used_bytes).to eq(params['disk.used'])
          expect(tasked_node.total_bytes).to eq(params['disk.all'])
          expect(tasked_node.indexed_bytes).to eq 0
          expect(tasked_node.metadata['name']).to eq(params['node.name'])
          expect(tasked_node.metadata['task_count']).to eq(params['node.task_count'])
          expect(tasked_node.metadata['concurrency']).to eq(params['node.concurrency'])
        end
      end

      context 'when node already exists for given UUID' do
        it 'returns existing node and updates correct attributes' do
          node.update!(uuid: params['uuid'])

          expect(tasked_node).to be_persisted
          expect(tasked_node.id).to eq(node.id)
          expect(tasked_node.index_base_url).to eq(params['node.url'])
          expect(tasked_node.search_base_url).to eq(params['node.search_url'])
          expect(tasked_node.uuid).to eq(params['uuid'])
          expect(tasked_node.last_seen_at).to eq(Time.zone.now)
          expect(tasked_node.used_bytes).to eq(params['disk.used'])
          expect(tasked_node.total_bytes).to eq(params['disk.all'])
          expect(tasked_node.indexed_bytes).to eq 0
          expect(tasked_node.metadata['name']).to eq(params['node.name'])
        end

        it 'allows creation of another node with the same URL' do
          node.update!(index_base_url: params['node.url'], search_base_url: params['node.url'])

          expect(tasked_node.save).to eq(true)
        end
      end
    end

    context 'when disk.indexed is present' do
      let(:params) { base_params.merge('disk.indexed' => 2416879) }

      it 'sets indexed_bytes to the disk.indexed from params' do
        expect(tasked_node.indexed_bytes).to eq(params['disk.indexed'])
      end
    end
  end

  describe '.backoff' do
    it 'returns a NodeBackoff' do
      expect(::Search::Zoekt::NodeBackoff).to receive(:new).with(node).and_return(:backoff)
      expect(node.backoff).to eq(:backoff)
    end
  end

  describe '.metadata_json' do
    it 'returns a json with metadata' do
      node.update!(metadata: { name: 'test_name', task_count: 100, concurrency: 10 })
      expected_json = {
        'zoekt.node_name' => 'test_name',
        'zoekt.node_id' => node.id,
        'zoekt.indexed_bytes' => 0,
        'zoekt.used_bytes' => node.used_bytes,
        'zoekt.total_bytes' => node.total_bytes,
        'zoekt.task_count' => 100,
        'zoekt.concurrency' => 10
      }

      expect(node.metadata_json).to eq(expected_json)
    end

    it 'does not return empty keys' do
      node.update!(metadata: { name: 'another_name' })
      expected_json = {
        'zoekt.node_name' => 'another_name',
        'zoekt.node_id' => node.id,
        'zoekt.indexed_bytes' => 0,
        'zoekt.used_bytes' => node.used_bytes,
        'zoekt.total_bytes' => node.total_bytes
      }

      expect(node.metadata_json).to eq(expected_json)
    end
  end
end
