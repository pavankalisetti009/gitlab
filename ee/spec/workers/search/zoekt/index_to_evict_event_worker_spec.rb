# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::IndexToEvictEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { Search::Zoekt::IndexToEvictEvent.new(data: data) }

  let_it_be(:indices_in_event) { create_list(:zoekt_index, 3, watermark_level: :critical_watermark_exceeded) }
  let_it_be(:index_ids) { indices_in_event.map(&:id) }

  let(:data) do
    { index_ids: index_ids }
  end

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    it 'evicts associated replicas' do
      expect { consume_event(subscriber: described_class, event: event) }.to change {
        ::Search::Zoekt::Replica.count
      }.by(-3)
    end
  end
end
