# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::IndexOverWatermarkEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { Search::Zoekt::IndexOverWatermarkEvent.new(data: data) }

  let_it_be(:watermark) { Search::Zoekt::Index::STORAGE_LOW_WATERMARK }
  let_it_be(:idx) { create(:zoekt_index, reserved_storage_bytes: max_storage_bytes) }
  let_it_be(:idx_2) { create(:zoekt_index) }
  let_it_be(:index_ids) { [idx.id] }
  let_it_be(:max_storage_bytes) { 100 }
  let_it_be(:idx_project) { create(:project, namespace_id: idx.namespace_id) }
  let_it_be(:idx_project_2) { create(:project, namespace_id: idx_2.namespace_id) }
  let_it_be(:repo) do
    idx.zoekt_repositories.create!(zoekt_index: idx, project: idx_project, state: :ready,
      size_bytes: max_storage_bytes * watermark)
  end

  let_it_be(:repo_2) do
    idx.zoekt_repositories.create!(zoekt_index: idx_2, project: idx_project_2, state: :ready, size_bytes: 1)
  end

  let(:data) do
    { index_ids: index_ids, watermark: watermark }
  end

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    context 'when there is an index that is over low storage watermark' do
      it 'updates the index to be watermarked' do
        expect do
          consume_event(subscriber: described_class, event: event)
        end.to change { Search::Zoekt::Index.low_watermark_exceeded.count }.from(0).to(1)
      end
    end

    context 'when there is an index that is over high storage watermark' do
      let_it_be(:watermark) { Search::Zoekt::Index::STORAGE_HIGH_WATERMARK }

      it 'updates the index to be watermarked' do
        expect do
          consume_event(subscriber: described_class, event: event)
        end.to change { Search::Zoekt::Index.high_watermark_exceeded.count }.from(0).to(1)
      end
    end

    context 'when there is an unknown watermark value' do
      let_it_be(:watermark) { 0.1 }

      it 'raises an exception for unknown watermark' do
        expect do
          consume_event(subscriber: described_class, event: event)
        end.to raise_error(/unhandled watermark state/i)
      end
    end
  end
end
