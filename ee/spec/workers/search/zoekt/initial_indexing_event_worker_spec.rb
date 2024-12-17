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
    [namespace, namespace.children.first, namespace.children.first.children.first].each do |n|
      create(:project, namespace: n)
    end
  end

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    context 'when metadata does not have project_id_from and project_id_to' do
      it 'creates pending zoekt_repositories for each project move the index to initializing' do
        expect(zoekt_repositories_for_index(zoekt_index)).to be_empty
        expect { consume_event(subscriber: described_class, event: event) }
          .to change { zoekt_index.reload.state }.from('pending').to('initializing')
        expect(zoekt_repositories_for_index(zoekt_index).count).to eq namespace.all_project_ids.count
        expect(zoekt_repositories_for_index(zoekt_index).all?(&:pending?)).to be true
      end
    end

    context 'when metadata has project_id_from and project_id_to' do
      let(:project_id_from) { namespace.all_project_ids.first.id }
      let(:project_id_to) { namespace.all_project_ids.second.id }
      let(:expected_project_ids) { Project.where(id: project_id_from..project_id_to).pluck(:id) }

      before do
        zoekt_index.update!(metadata: { project_id_from: project_id_from, project_id_to: project_id_to })
      end

      it 'creates pending zoekt_repositories for project_ids of range project_id_from and project_id_to' do
        expect(zoekt_repositories_for_index(zoekt_index)).to be_empty
        expect { consume_event(subscriber: described_class, event: event) }
          .to change { zoekt_index.reload.state }.from('pending').to('initializing')
        expect(zoekt_repositories_for_index(zoekt_index).pluck(:project_id)).to match_array(expected_project_ids)
        expect(zoekt_repositories_for_index(zoekt_index).all?(&:pending?)).to be true
      end
    end

    context 'when metadata has only project_id_from' do
      let(:project_id_from) { namespace.all_project_ids.second.id }
      let(:expected_project_ids) { Project.where(id: project_id_from..).pluck(:id) }

      before do
        zoekt_index.update!(metadata: { project_id_from: project_id_from })
      end

      it 'creates pending zoekt_repositories for all project_ids from project_id_from' do
        expect(zoekt_repositories_for_index(zoekt_index)).to be_empty
        expect { consume_event(subscriber: described_class, event: event) }
          .to change { zoekt_index.reload.state }.from('pending').to('initializing')
        expect(zoekt_repositories_for_index(zoekt_index).pluck(:project_id)).to match_array(expected_project_ids)
        expect(zoekt_repositories_for_index(zoekt_index).all?(&:pending?)).to be true
      end
    end

    context 'when index is not in pending' do
      let(:data) do
        { index_id: zoekt_index.id }
      end

      before do
        zoekt_index.initializing!
      end

      it 'does not creates zoekt_repositories' do
        consume_event(subscriber: described_class, event: event)
        expect(zoekt_repositories_for_index(zoekt_index).count).to eq 0
      end
    end

    context 'when index can not be found' do
      let(:data) do
        { index_id: non_existing_record_id }
      end

      it 'does not creates zoekt_repositories' do
        consume_event(subscriber: described_class, event: event)
        expect(zoekt_repositories_for_index(zoekt_index).count).to eq 0
      end
    end
  end

  def zoekt_repositories_for_index(index)
    Search::Zoekt::Repository.where(zoekt_index_id: index.id)
  end
end
