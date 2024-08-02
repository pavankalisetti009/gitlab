# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Work Item Limited Indexing', :elastic, :sidekiq_inline, feature_category: :global_search do
  shared_examples 'when namespace is added to limiting setting adds work_item to index' do
    context 'if the namespace is removed from the list' do
      it 'adds the work_item to elasticsearch', :elastic_clean, :sidekiq_inline do
        expect(items_in_index(index_name)).to be_empty
        indexed_namespace = build(:elasticsearch_indexed_namespace, namespace: namespace)

        indexed_namespace.save!
        ensure_elasticsearch_index!
        expect(items_in_index(index_name)).to eq([work_item.id])
      end
    end
  end

  shared_examples 'when namespace is removed from limiting setting deletes work_item from index' do
    context 'if the namespace is removed from the list' do
      it 'deletes the work_item from elasticsearch', :elastic_clean, :sidekiq_inline do
        indexed_namespace = create(:elasticsearch_indexed_namespace, namespace: namespace)
        ensure_elasticsearch_index!
        expect(items_in_index(index_name)).to eq([work_item.id])

        indexed_namespace.destroy!

        ensure_elasticsearch_index!
        expect(items_in_index(index_name)).to be_empty
      end
    end
  end

  context 'when limited indexing is enabled' do
    let(:index_name) { ::Search::Elastic::References::WorkItem.index }

    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
      stub_ee_application_setting(elasticsearch_limit_indexing?: true)
    end

    context 'with group level namespace' do
      let_it_be(:namespace) { create(:group) }

      describe 'group level work item respects limited indexing' do
        let(:group_level_work_item) { true }
        let_it_be_with_refind(:work_item) do
          create(:work_item, :group_level, :epic_with_legacy_epic, namespace: namespace)
        end

        it_behaves_like 'when namespace is added to limiting setting adds work_item to index'
        it_behaves_like 'when namespace is removed from limiting setting deletes work_item from index'
      end

      describe 'work item respects limited indexing' do
        let(:group_level_work_item) { false }
        let_it_be_with_refind(:work_item) { create(:work_item, namespace: namespace) }

        it_behaves_like 'when namespace is added to limiting setting adds work_item to index'
        it_behaves_like 'when namespace is removed from limiting setting deletes work_item from index'
      end
    end
  end
end
