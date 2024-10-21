# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20241003142503_add_embedding_to_work_items.rb')

RSpec.describe AddEmbeddingToWorkItems, feature_category: :global_search do
  let(:version) { 20241003142503 }
  let(:migration) { described_class.new(version) }

  describe 'migration' do
    before do
      skip 'migration is skipped' if migration.skip_migration?
    end

    describe 'migration process', :elastic, :sidekiq_inline do
      include_examples 'migration adds mapping'
    end

    describe '#new_mappings' do
      it 'returns the correct mapping for Elasticsearch' do
        expected_mapping = {
          routing: {
            type: 'text'
          },
          embedding_0: {
            type: 'dense_vector',
            dims: 768,
            similarity: 'cosine',
            index: true
          }
        }
        expect(migration.new_mappings).to eq(expected_mapping)
      end
    end
  end

  describe 'skip_migration?' do
    let(:helper) { Gitlab::Elastic::Helper.default }

    before do
      allow(Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
      allow(helper).to receive(:matching_distribution?).and_return(vectors_supported)
      described_class.skip_if -> do
        !Gitlab::Elastic::Helper.default.matching_distribution?(:elasticsearch, min_version: '8.0.0')
      end
    end

    context 'if vectors are supported' do
      let(:vectors_supported) { true }

      it 'returns false' do
        expect(migration.skip_migration?).to be_falsey
      end
    end

    context 'if vectors are not supported' do
      let(:vectors_supported) { false }

      it 'returns true' do
        expect(migration.skip_migration?).to be_truthy
      end
    end
  end
end
