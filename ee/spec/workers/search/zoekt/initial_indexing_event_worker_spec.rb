# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::InitialIndexingEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let_it_be(:namespace) { create(:group, :with_hierarchy, children: 1, depth: 3) }
  let(:event) { Search::Zoekt::InitialIndexingEvent.new(data: data) }
  let_it_be(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace) }
  let_it_be_with_reload(:zoekt_index) do
    create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace, namespace_id: namespace.id)
  end

  let(:data) do
    { index_id: zoekt_index.id }
  end

  before do
    [namespace, namespace.children.first].each { |n| create(:project, namespace: n) }
  end

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    it 'calls IndexingTaskService on each project of the indexed namespace and move the index to initializing' do
      namespace.all_projects.each do |project|
        expect(::Search::Zoekt::IndexingTaskService).to receive(:execute).with(project.id, :index_repo)
      end
      expect { consume_event(subscriber: described_class, event: event) }
        .to change { zoekt_index.reload.state }.from('pending').to('initializing')
    end

    context 'when index is not in pending' do
      let(:data) do
        { index_id: zoekt_index.id }
      end

      before do
        zoekt_index.initializing!
      end

      it 'does not calls IndexingTaskService' do
        expect(::Search::Zoekt::IndexingTaskService).not_to receive(:execute)
        consume_event(subscriber: described_class, event: event)
      end
    end

    context 'when index can not be found' do
      let(:data) do
        { index_id: non_existing_record_id }
      end

      it 'does not calls IndexingTaskService' do
        expect(::Search::Zoekt::IndexingTaskService).not_to receive(:execute)
        consume_event(subscriber: described_class, event: event)
      end
    end
  end
end
