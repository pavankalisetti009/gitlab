# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::NodeWithNegativeUnclaimedStorageEventWorker, :zoekt_settings_enabled,
  feature_category: :global_search do
  let(:event) { Search::Zoekt::NodeWithNegativeUnclaimedStorageEvent.new(data: data) }

  let_it_be(:node) { create(:zoekt_node, :enough_free_space) }
  let_it_be(:index) { create(:zoekt_index, node: node) }
  let_it_be(:negative_node) { create(:zoekt_node, :enough_free_space) }
  let_it_be(:negative_index) do
    create(:zoekt_index, reserved_storage_bytes: negative_node.total_bytes * 2, node: negative_node)
  end

  let(:data) do
    { node_ids: [node.id, negative_node.id] }
  end

  it_behaves_like 'subscribes to event'

  it 'has the `until_executed` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  it_behaves_like 'an idempotent worker' do
    it 'processes nodes with negative unclaimed storage bytes' do
      expect do
        consume_event(subscriber: described_class, event: event)
      end.to publish_event(Search::Zoekt::IndexToEvictEvent).with({ index_ids: [negative_index.id] })
    end
  end
end
