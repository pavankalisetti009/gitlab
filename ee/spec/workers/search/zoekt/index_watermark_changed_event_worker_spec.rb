# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::IndexWatermarkChangedEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { Search::Zoekt::IndexWatermarkChangedEvent.new(data: data) }

  let_it_be(:watermark_level) { 'low_watermark_exceeded' }
  let_it_be(:indices_in_event) { create_list(:zoekt_index, 3) }
  let_it_be(:index_ids) { indices_in_event.map(&:id) }
  let_it_be(:max_storage_bytes) { 100 }

  let(:data) do
    { index_ids: index_ids, watermark_level: watermark_level }
  end

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    it 'calls `update_reserved_storage_bytes` for each index' do
      expect(::Search::Zoekt::Index).to receive(:id_in).with(index_ids).and_return(indices_in_event)
      expect(indices_in_event).to receive(:each_batch).and_yield(indices_in_event)

      indices_in_event.each do |zkt_index| # rubocop:disable RSpec/IteratedExpectation -- Not applicable
        expect(zkt_index).to receive(:update_reserved_storage_bytes!)
      end

      consume_event(subscriber: described_class, event: event)
    end
  end
end
