# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::RepoMarkedAsToDeleteEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { Search::Zoekt::RepoMarkedAsToDeleteEvent.new(data: data) }

  let_it_be(:repo) { create(:zoekt_repository) }
  let_it_be(:another_repo) { create(:zoekt_repository) }
  let_it_be(:zoekt_repo_ids) { [repo].map(&:id) }

  let(:data) do
    { zoekt_repo_ids: zoekt_repo_ids }
  end

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    it 'creates a delete repo task for all repos in the list' do
      expect do
        consume_event(subscriber: described_class, event: event)
      end.to change { Search::Zoekt::Task.where(project_identifier: repo.project_identifier).count }.from(0).to(1)
    end
  end
end
