# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::OrphanedRepoEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { Search::Zoekt::OrphanedRepoEvent.new(data: data) }

  let_it_be(:zoekt_repo_ids) { create_list(:zoekt_repository, 5, state: :pending).map(&:id) }
  let_it_be(:non_orphaned_zoekt_repo) { create(:zoekt_repository, state: :pending) }

  let(:data) do
    { zoekt_repo_ids: zoekt_repo_ids }
  end

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    it 'marks repositories in the event as orphaned' do
      expect do
        consume_event(subscriber: described_class, event: event)
      end.to change { Search::Zoekt::Repository.orphaned.count }.from(0).to(zoekt_repo_ids.length)
    end
  end
end
