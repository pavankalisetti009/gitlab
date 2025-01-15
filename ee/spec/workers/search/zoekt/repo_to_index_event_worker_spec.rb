# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::RepoToIndexEventWorker, feature_category: :global_search do
  let(:event) { Search::Zoekt::RepoToIndexEvent.new(data: {}) }

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    context 'when zoekt is disabled' do
      before do
        allow(Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return false
      end

      it 'does not create any indexing tasks' do
        expect do
          consume_event(subscriber: described_class, event: event)
        end.not_to change { Search::Zoekt::Task.count }
      end
    end

    context 'when zoekt is enabled' do
      before do
        allow(Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return true
      end

      it 'creates indexing tasks for Search::Zoekt::Repository' do
        batch_size = 2
        create_list(:zoekt_repository, batch_size + 1)
        stub_const("Search::Zoekt::RepoToIndexEventWorker::BATCH_SIZE", batch_size)
        expect do
          consume_event(subscriber: described_class, event: event)
        end.to change { Search::Zoekt::Task.count }.from(0).to(batch_size)
      end
    end
  end
end
