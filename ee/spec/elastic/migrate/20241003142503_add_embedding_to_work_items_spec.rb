# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20241003142503_add_embedding_to_work_items.rb')

RSpec.describe AddEmbeddingToWorkItems, feature_category: :global_search do
  let(:version) { 20241003142503 }
  let(:migration) { described_class.new(version) }

  describe 'migration', :elastic, :sidekiq_inline do
    before do
      skip 'migration is skipped' if migration.skip_migration?
    end

    include_examples 'migration adds mapping'
  end

  # rubocop:disable RSpec/AnyInstanceOf -- multiple instances of helper
  describe '#new_mappings' do
    context 'when using Elasticsearch 8 or higher' do
      before do
        allow_any_instance_of(Gitlab::Elastic::Helper).to receive(:matching_distribution?)
          .with(:elasticsearch, min_version: '8.0.0').and_return(true)
        allow_any_instance_of(Gitlab::Elastic::Helper).to receive(:matching_distribution?)
          .with(:opensearch).and_return(false)
      end

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

    context 'when using OpenSearch' do
      before do
        allow_next_instance_of(Gitlab::Elastic::Helper) do |helper|
          allow(helper).to receive(:matching_distribution?).with(:elasticsearch, min_version: '8.0.0').and_return(false)
          allow(helper).to receive(:matching_distribution?).with(:opensearch).and_return(true)
        end

        allow_any_instance_of(Gitlab::Elastic::Helper).to receive(:matching_distribution?)
          .with(:elasticsearch, min_version: '8.0.0').and_return(false)
        allow_any_instance_of(Gitlab::Elastic::Helper).to receive(:matching_distribution?)
          .with(:opensearch).and_return(true)
      end

      it 'returns the correct mapping for OpenSearch' do
        expected_mapping = {
          routing: {
            type: 'text'
          },
          embedding_0: {
            type: 'knn_vector',
            dimension: 768,
            method: {
              name: 'hnsw',
              space_type: 'cosinesimil',
              parameters: {
                ef_construction: 100,
                m: 16
              }
            }
          }
        }
        expect(migration.new_mappings).to eq(expected_mapping)
      end
    end
  end
  # rubocop:enable RSpec/AnyInstanceOf

  describe 'skip_migration?' do
    let(:helper) { Gitlab::Elastic::Helper.default }

    before do
      allow(Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
      allow(helper).to receive(:vectors_supported?).and_return(vectors_supported)
      described_class.skip_if -> { !Gitlab::Elastic::Helper.default.vectors_supported?(:elasticsearch) }
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
