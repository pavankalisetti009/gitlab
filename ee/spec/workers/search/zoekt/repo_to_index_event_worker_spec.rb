# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::RepoToIndexEventWorker, feature_category: :global_search do
  let(:data) do
    { zoekt_repo_ids: Search::Zoekt::Repository.pending_or_initializing.pluck_primary_key }
  end

  let(:event) { Search::Zoekt::RepoToIndexEvent.new(data: data) }
  let(:target_scope) { Search::Zoekt::Repository.id_in(data[:zoekt_repo_ids]) }

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    context 'when zoekt is disabled' do
      before do
        allow(Search::Zoekt).to receive(:enabled?).and_return false
      end

      it 'does not calls message chain pending_or_initializing.create_bulk_tasks on Search::Zoekt::Repository' do
        expect(Search::Zoekt::Repository).not_to receive(:id_in)
        consume_event(subscriber: described_class, event: event)
      end
    end

    context 'when zoekt is enabled' do
      before do
        allow(Search::Zoekt).to receive(:enabled?).and_return true
      end

      it 'calls message chain pending_or_initializing.create_bulk_tasks on Search::Zoekt::Repository' do
        expect(Search::Zoekt::Repository).to receive(:id_in).with(data[:zoekt_repo_ids]).and_return target_scope
        expect(target_scope).to receive_message_chain(:pending_or_initializing, :create_bulk_tasks)
        consume_event(subscriber: described_class, event: event)
      end
    end
  end
end
