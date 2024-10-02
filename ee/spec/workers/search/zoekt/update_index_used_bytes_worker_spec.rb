# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::UpdateIndexUsedBytesWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { Search::Zoekt::TaskSucceededEvent.new(data: data) }

  let_it_be(:zoekt_task) { create(:zoekt_task) }

  let_it_be(:index) { create(:zoekt_index) }
  let_it_be(:repo) { create(:zoekt_repository, zoekt_index: index) }
  let_it_be(:another_repo) { create(:zoekt_repository, zoekt_index: index) }

  let(:data) do
    { zoekt_repository_id: repo.id, task_id: zoekt_task.id }
  end

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :always

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    let(:logger) { instance_double(::Search::Zoekt::Logger) }

    before do
      allow(::Search::Zoekt::Logger).to receive(:build).and_return(logger)
    end

    it 'resizes an index used_storage_bytes' do
      expect do
        consume_event(subscriber: described_class, event: event)
      end.to change {
        Search::Zoekt::Index.find(index.id).used_storage_bytes
      }.from(0).to(repo.size_bytes + another_repo.size_bytes)
    end
  end
end
