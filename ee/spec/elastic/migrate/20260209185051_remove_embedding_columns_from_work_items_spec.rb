# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20260209185051_remove_embedding_columns_from_work_items.rb')

RSpec.describe RemoveEmbeddingColumnsFromWorkItems, :elastic, :sidekiq_inline, feature_category: :global_search do
  let(:version) { 20260209185051 }
  let(:migration) { described_class.new(version) }
  let(:index_name) { WorkItem.__elasticsearch__.index_name }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'migration_options' do
    it 'has migration options set', :aggregate_failures do
      expect(migration).to be_batched
      expect(migration.throttle_delay).to eq(1.minute)
    end
  end

  describe '#fields_to_remove' do
    it 'returns the embedding columns' do
      expect(migration.send(:fields_to_remove)).to match_array(%w[embedding_0 embedding_1])
    end
  end
end
