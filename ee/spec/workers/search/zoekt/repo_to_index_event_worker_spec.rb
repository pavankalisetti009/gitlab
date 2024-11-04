# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::RepoToIndexEventWorker, feature_category: :global_search do
  let(:event) { Search::Zoekt::RepoToIndexEvent.new(data: data) }
  let_it_be(:empty_project) { create(:project, :empty_repo) }
  let_it_be_with_reload(:pending_repo_empty_project) { create(:zoekt_repository, project: empty_project) }
  let_it_be_with_reload(:pending_repo) { create(:zoekt_repository, :with_repo) }
  let_it_be_with_reload(:pending_repo_without_project) do
    create(:zoekt_repository, project: nil, project_identifier: non_existing_record_id)
  end

  let_it_be_with_reload(:initializing_repo) { create(:zoekt_repository, :with_repo, state: :initializing) }

  let(:data) do
    { zoekt_repo_ids: Search::Zoekt::Repository.pending_or_initializing.pluck_primary_key }
  end

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    it 'calls Search::Zoekt.index_async for non empty repos and moves zoekt_repository to ready for empty repos' do
      expect(Search::Zoekt).to receive(:index_async).with(pending_repo.project_identifier)
      expect(Search::Zoekt).to receive(:index_async).with(initializing_repo.project_identifier)
      consume_event(subscriber: described_class, event: event)
      expect(pending_repo.reload).to be_pending
      expect(initializing_repo.reload).to be_initializing
      expect(pending_repo_empty_project.reload).to be_ready
    end
  end
end
