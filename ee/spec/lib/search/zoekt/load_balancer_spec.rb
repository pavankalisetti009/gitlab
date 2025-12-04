# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::LoadBalancer, :clean_gitlab_redis_cache, feature_category: :global_search do
  let_it_be(:node1) { create(:zoekt_node) }
  let_it_be(:node2) { create(:zoekt_node) }
  let(:nodes) { [node1, node2] }
  let(:balancer) { described_class.new(nodes) }

  describe '.distribution' do
    it 'returns the load for each node' do
      balancer.increase_load(node1, weight: 2)
      balancer.increase_load(node2, weight: 3)

      result = described_class.distribution(nodes)
      expect(result).to contain_exactly(
        a_hash_including(node_id: node1.id, current_load: 2.0),
        a_hash_including(node_id: node2.id, current_load: 3.0)
      )
    end
  end

  describe '#distribution' do
    it 'returns the load for each node' do
      balancer.increase_load(node1, weight: 1.5)
      balancer.increase_load(node2, weight: 0.5)

      result = balancer.distribution
      expect(result).to contain_exactly(
        a_hash_including(node_id: node1.id, current_load: 1.5),
        a_hash_including(node_id: node2.id, current_load: 0.5)
      )
    end
  end

  describe '#pick' do
    it 'always returns the node with the lowest load' do
      balancer.increase_load(node1, weight: 5)
      balancer.increase_load(node2, weight: 1)
      5.times do
        expect(balancer.pick).to eq(node2)
      end
    end

    it 'returns a node if all loads are zero' do
      expect(nodes).to include(balancer.pick)
    end

    context 'when there is only one node' do
      let(:nodes) { [node1] }

      it 'always returns that node' do
        5.times do
          expect(balancer.pick).to eq(node1)
        end
      end
    end
  end

  describe '#increase_load and #decrease_load' do
    it 'increments and decrements the node load' do
      expect(balancer.distribution.find { |h| h[:node_id] == node1.id }[:current_load]).to eq(0.0)
      balancer.increase_load(node1, weight: 2.5)
      expect(balancer.distribution.find { |h| h[:node_id] == node1.id }[:current_load]).to eq(2.5)

      balancer.decrease_load(node1, weight: 1.5)
      expect(balancer.distribution.find { |h| h[:node_id] == node1.id }[:current_load]).to eq(1.0)

      balancer.decrease_load(node1, weight: 1.0)
      expect(balancer.distribution.find { |h| h[:node_id] == node1.id }[:current_load]).to eq(0.0)
    end

    it 'removes the key if load goes to zero or below' do
      balancer.increase_load(node1, weight: 1)
      balancer.decrease_load(node1, weight: 2)
      expect(balancer.distribution.find { |h| h[:node_id] == node1.id }[:current_load]).to eq(0.0)
    end
  end

  describe '#reset!' do
    it 'resets the load for all nodes' do
      balancer.increase_load(node1, weight: 2)
      balancer.increase_load(node2, weight: 3)
      expect(balancer.distribution.pluck(:current_load)).to all(be > 0)

      balancer.reset!
      expect(balancer.distribution.pluck(:current_load)).to all(eq(0.0))
    end
  end

  describe '#initialize' do
    it 'raises an error if nodes are empty' do
      expect { described_class.new([]) }.to raise_error(ArgumentError)
    end
  end
end
