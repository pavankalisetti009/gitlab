# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::OrphanedIndexEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { Search::Zoekt::OrphanedIndexEvent.new(data: data) }

  let_it_be(:index_ids) { create_list(:zoekt_index, 5).map(&:id) }

  let(:data) do
    { index_ids: index_ids }
  end

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    it 'marks indices in the event as orphaned' do
      expect do
        consume_event(subscriber: described_class, event: event)
      end.to change { Search::Zoekt::Index.orphaned.count }.from(0).to(index_ids.length)
    end
  end
end
