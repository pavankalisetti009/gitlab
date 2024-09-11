# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::IndexMarkedAsToDeleteEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { Search::Zoekt::IndexMarkedAsToDeleteEvent.new(data: data) }

  let_it_be(:idx) { create(:zoekt_index) }
  let_it_be(:index_ids) { [idx].map(&:id) }

  let(:data) do
    { index_ids: index_ids }
  end

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    context 'when there an index has zoekt repositories' do
      let_it_be(:idx_project) { create(:project, namespace_id: idx.namespace_id) }
      let_it_be(:repo) { idx.zoekt_repositories.create!(zoekt_index: idx, project: idx_project, state: :ready) }

      it 'marks the repositories to be deleted' do
        expect do
          consume_event(subscriber: described_class, event: event)
        end.to change { Search::Zoekt::Repository.find(repo.id).state }.from("ready").to("pending_deletion")
      end

      it 'does not destroy the index' do
        expect do
          consume_event(subscriber: described_class, event: event)
        end.not_to change { Search::Zoekt::Index.count }
      end
    end

    context 'when there is an index that does not have any zoekt repositories' do
      it 'destroys the zoekt index' do
        expect do
          consume_event(subscriber: described_class, event: event)
        end.to change { Search::Zoekt::Index.count }.from(1).to(0)
      end
    end
  end
end
