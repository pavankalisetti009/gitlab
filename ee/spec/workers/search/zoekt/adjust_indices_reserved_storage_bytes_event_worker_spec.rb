# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::AdjustIndicesReservedStorageBytesEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { Search::Zoekt::AdjustIndicesReservedStorageBytesEvent.new(data: data) }
  let_it_be(:node) { create(:zoekt_node, :enough_free_space) }
  let_it_be(:overprovisioned_pending_index) { create(:zoekt_index, :overprovisioned) }
  let_it_be(:overprovisioned_ready_index) { create(:zoekt_index, :overprovisioned, :ready) }
  let_it_be(:high_watermark_exceeded_pending_index) do
    create(:zoekt_index, :high_watermark_exceeded, node: node)
  end

  let_it_be(:high_watermark_exceeded_ready_index) do
    create(:zoekt_index, :high_watermark_exceeded, :ready, node: node)
  end

  let_it_be(:healthy_index) { create(:zoekt_index, :healthy) }
  let_it_be(:index_ids) { Search::Zoekt::Index.pluck_primary_key }

  let(:data) do
    { index_ids: index_ids }
  end

  it 'has the `until_executed` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    it 'calls update_reserved_storage_bytes! on the Search::Zoekt::Index.should_be_reserved_storage_bytes_adjusted' do
      consume_event(subscriber: described_class, event: event)
      expect(overprovisioned_pending_index.reload).to be_overprovisioned
      expect(overprovisioned_ready_index.reload).to be_healthy
      expect(high_watermark_exceeded_pending_index.reload).to be_healthy
      expect(high_watermark_exceeded_ready_index.reload).to be_healthy
      expect(healthy_index.reload).to be_healthy
    end
  end
end
