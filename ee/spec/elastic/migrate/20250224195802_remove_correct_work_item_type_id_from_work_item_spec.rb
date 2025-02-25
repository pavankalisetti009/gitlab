# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250224195802_remove_correct_work_item_type_id_from_work_item.rb')

RSpec.describe RemoveCorrectWorkItemTypeIdFromWorkItem, :elastic_delete_by_query, :sidekiq_inline, feature_category: :global_search do
  let(:version) { 20250224195802 }
  let(:migration) { described_class.new(version) }
  let(:client) { ::Gitlab::Search::Client.new }
  let(:work_items) { create_list(:work_item, 6) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    work_items
    ensure_elasticsearch_index!
  end

  describe 'migration options' do
    it 'has migration options set', :aggregate_failures do
      expect(migration).to be_batched
      expect(migration.throttle_delay).to eq(1.minute)
    end
  end

  describe '#completed?' do
    context 'when correct_work_item_type_id is present in the mapping' do
      before do
        add_correct_work_item_type_id_in_mapping!
      end

      context 'when some documents have the value for correct_work_item_type_id set' do
        before do
          add_correct_work_item_type_id_value_to_documents!(3)
        end

        it 'returns false' do
          expect(migration.completed?).to be false
        end
      end

      context 'when no documents have the value for correct_work_item_type_id set' do
        it 'returns true' do
          expect(migration.completed?).to be true
        end
      end
    end

    context 'when correct_work_item_type_id is not present in the mapping' do
      it 'returns true' do
        expect(migration.completed?).to be true
      end
    end
  end

  describe '#migrate' do
    let(:original_target_doc_count) { 5 }
    let(:batch_size) { 2 }

    before do
      add_correct_work_item_type_id_in_mapping!
      add_correct_work_item_type_id_value_to_documents!(original_target_doc_count)
      allow(migration).to receive(:batch_size).and_return(batch_size)
    end

    it 'completes the migration in batches' do
      expect(documents_count_with_correct_work_item_type_id).to eq original_target_doc_count
      expect(migration.completed?).to be false
      migration.migrate
      expect(migration.completed?).to be false
      expect(documents_count_with_correct_work_item_type_id).to eq original_target_doc_count - batch_size
      10.times do
        break if migration.completed?

        migration.migrate
        sleep 0.01
      end
      expect(migration.completed?).to be true
      expect(documents_count_with_correct_work_item_type_id).to eq 0
    end
  end

  def add_correct_work_item_type_id_in_mapping!
    client.indices.put_mapping(index: ::Search::Elastic::References::WorkItem.index,
      body: { properties: { correct_work_item_type_id: { type: 'long' } } }
    )
  end

  def add_correct_work_item_type_id_value_to_documents!(count)
    client.update_by_query(index: ::Search::Elastic::References::WorkItem.index, refresh: true, body: {
      script: { source: "ctx._source.correct_work_item_type_id=20" }, max_docs: count
    })
  end

  def documents_count_with_correct_work_item_type_id
    client.count(index: ::Search::Elastic::References::WorkItem.index,
      body: { query: { bool: { must: { exists: { field: 'correct_work_item_type_id' } } } } }
    )['count']
  end
end
