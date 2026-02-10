# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Collection, feature_category: :global_search do
  subject(:collection) { create(:ai_active_context_collection) }

  it { is_expected.to be_valid }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_length_of(:name).is_at_most(255) }
  it { is_expected.to validate_uniqueness_of(:name).scoped_to(:connection_id) }

  it { is_expected.to validate_presence_of(:number_of_partitions) }
  it { is_expected.to validate_numericality_of(:number_of_partitions).is_greater_than_or_equal_to(1).only_integer }

  it { is_expected.to validate_presence_of(:connection_id) }

  it { is_expected.to belong_to(:connection).class_name('Ai::ActiveContext::Connection') }

  describe 'metadata' do
    it 'is valid when empty' do
      collection.metadata = {}
      expect(collection).to be_valid
    end

    it 'is valid with search_embedding_version as a positive integer' do
      collection.metadata = { search_embedding_version: 1 }
      expect(collection).to be_valid
    end

    it 'is valid with search_embedding_version as zero' do
      collection.metadata = { search_embedding_version: 0 }
      expect(collection).to be_valid
    end

    it 'is valid with search_embedding_version as null' do
      collection.metadata = { search_embedding_version: nil }
      expect(collection).to be_valid
    end

    it 'is invalid with search_embedding_version as a negative number' do
      collection.metadata = { search_embedding_version: -1 }
      expect(collection).not_to be_valid
      expect(collection.errors[:metadata]).to include('must be a valid json schema')
    end

    it 'is valid with indexing_embedding_versions as an array of integers' do
      collection.metadata = { indexing_embedding_versions: [0, 1, 2] }
      expect(collection).to be_valid
    end

    it 'is valid with indexing_embedding_versions as an empty array' do
      collection.metadata = { indexing_embedding_versions: [] }
      expect(collection).to be_valid
    end

    it 'is invalid with indexing_embedding_versions containing negative numbers' do
      collection.metadata = { indexing_embedding_versions: [1, -1, 3] }
      expect(collection).not_to be_valid
      expect(collection.errors[:metadata]).to include('must be a valid json schema')
    end

    it 'is invalid when indexing_embedding_versions is not an array' do
      collection.metadata = { indexing_embedding_versions: 1 }
      expect(collection).not_to be_valid
      expect(collection.errors[:metadata]).to include('must be a valid json schema')
    end

    it 'is valid with both search_embedding_version and indexing_embedding_versions' do
      collection.metadata = {
        search_embedding_version: 1,
        indexing_embedding_versions: [2, 3, 4]
      }
      expect(collection).to be_valid
    end

    it 'is valid with include_ref_fields as true' do
      collection.metadata = { include_ref_fields: true }
      expect(collection).to be_valid
    end

    it 'is invalid when include_ref_fields is null' do
      collection.metadata = { include_ref_fields: nil }
      expect(collection).not_to be_valid
      expect(collection.errors[:metadata]).to include('must be a valid json schema')
    end

    it 'is valid with collection_class as a string' do
      collection.metadata = { collection_class: 'A string' }
      expect(collection).to be_valid
    end

    it 'is valid with previous_embedding_field is null' do
      collection.metadata = { previous_embedding_field: nil }
      expect(collection).to be_valid
    end

    it 'is valid with previous_embedding_field as a string' do
      collection.metadata = { previous_embedding_field: 'prev_embedding' }
      expect(collection).to be_valid
    end

    describe 'embedding model properties' do
      where(:embedding_model) do
        [:current_indexing_embedding_model, :next_indexing_embedding_model, :search_embedding_model]
      end

      with_them do
        it 'is valid with string model_ref and field' do
          collection.metadata = { embedding_model => { model_ref: 'model_1', field: 'field_1' } }
          expect(collection).to be_valid
        end

        it 'is invalid without model_ref' do
          collection.metadata = { embedding_model => { field: 'field_1' } }
          expect(collection).not_to be_valid
        end

        it 'is invalid without field' do
          collection.metadata = { embedding_model => { model_ref: 'model_1' } }
          expect(collection).not_to be_valid
        end

        it 'is valid with model_type as a string' do
          collection.metadata = {
            embedding_model => { model_ref: 'model_1', field: 'field_1', model_type: 'self_hosted' }
          }
          expect(collection).to be_valid
        end

        it 'is valid with dimensions as a positive integer' do
          collection.metadata = { embedding_model => { model_ref: 'model_1', field: 'field_1', dimensions: 768 } }
          expect(collection).to be_valid
        end

        it 'is invalid with dimensions as 0' do
          collection.metadata = { embedding_model => { model_ref: 'model_1', field: 'field_1', dimensions: 0 } }
          expect(collection).not_to be_valid
        end

        it 'is invalid with dimensions as a negative integer' do
          collection.metadata = { embedding_model => { model_ref: 'model_1', field: 'field_1', dimensions: -1 } }
          expect(collection).not_to be_valid
        end
      end
    end

    it 'is invalid with arbitrary properties' do
      collection.metadata = { key: 'value' }
      expect(collection).not_to be_valid
      expect(collection.errors[:metadata]).to include('must be a valid json schema')
    end
  end

  describe 'options' do
    it 'is valid when empty' do
      collection.options = {}
      expect(collection).to be_valid
    end

    it 'is valid when values follow expected types' do
      collection.options = {
        queue_shard_count: 2,
        queue_shard_limit: 1000
      }

      expect(collection).to be_valid
    end

    it 'is valid when nullable values are nil' do
      collection.options = {
        queue_shard_count: nil,
        queue_shard_limit: nil
      }

      expect(collection).to be_valid
    end

    describe 'invalid options' do
      using RSpec::Parameterized::TableSyntax

      where(:key, :value) do
        :queue_shard_count | "some string"
        :queue_shard_count | 0

        :queue_shard_limit | "some string"
        :queue_shard_limit | 0
      end

      with_them do
        before do
          collection.options = { key => value }
        end

        it 'results in validation errors' do
          expect(collection).not_to be_valid
          expect(collection.errors[:options]).to include('must be a valid json schema')
        end
      end
    end
  end

  describe '.partition_for' do
    using RSpec::Parameterized::TableSyntax

    let(:collection) { create(:ai_active_context_collection, number_of_partitions: 5) }

    where(:routing_value, :partition_number) do
      1 | 0
      2 | 1
      3 | 3
      4 | 2
      5 | 3
      6 | 3
      7 | 4
      8 | 4
      9 | 2
      10 | 2
    end

    with_them do
      it 'always returns the same partition for a routing value' do
        expect(collection.partition_for(routing_value)).to eq(partition_number)
      end
    end
  end

  describe '#update_metadata!' do
    context 'with valid metadata' do
      it 'updates the metadata with valid values' do
        expect(collection.metadata).to eq({})

        collection.update_metadata!(search_embedding_version: 2)

        expect(collection.reload.metadata).to eq({ 'search_embedding_version' => 2 })
      end

      it 'merges with existing metadata' do
        collection.update_metadata!(search_embedding_version: 3)
        collection.update_metadata!(search_embedding_version: 4)

        expect(collection.reload.metadata).to eq({ 'search_embedding_version' => 4 })
      end

      it 'supports updating indexing_embedding_versions' do
        collection.update_metadata!(indexing_embedding_versions: [1, 2, 3])

        expect(collection.reload.metadata).to eq({ 'indexing_embedding_versions' => [1, 2, 3] })
      end

      it 'supports updating both search_embedding_version and indexing_embedding_versions' do
        collection.update_metadata!({
          search_embedding_version: 5,
          indexing_embedding_versions: [6, 7, 8]
        })

        expect(collection.reload.metadata).to eq({
          'search_embedding_version' => 5,
          'indexing_embedding_versions' => [6, 7, 8]
        })
      end

      it 'upserts and keeps existing metadata' do
        collection.update_metadata!(search_embedding_version: 5)
        collection.update_metadata!(indexing_embedding_versions: [6, 7, 8])

        expect(collection.reload.metadata).to eq({
          'search_embedding_version' => 5,
          'indexing_embedding_versions' => [6, 7, 8]
        })
      end
    end

    context 'with invalid metadata' do
      it 'raises an error when validation fails' do
        expect { collection.update_metadata!(search_embedding_version: -1) }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it 'does not change the metadata when validation fails' do
        collection.update_metadata!(search_embedding_version: 5)
        expect(collection.reload.metadata).to eq({ 'search_embedding_version' => 5 })

        expect { collection.update_metadata!(search_embedding_version: -1) }.to raise_error(ActiveRecord::RecordInvalid)
        expect(collection.reload.metadata).to eq({ 'search_embedding_version' => 5 })
      end
    end
  end

  describe '#update_options!' do
    it 'upserts and keeps existing options' do
      collection.update!(options: { queue_shard_count: 2 })

      collection.reload
      expect(collection.options.symbolize_keys).to eq({ queue_shard_count: 2 })

      collection.update_options!({ queue_shard_limit: 200 })

      collection.reload
      expect(collection.options.symbolize_keys).to eq({
        queue_shard_count: 2,
        queue_shard_limit: 200
      })
    end
  end

  describe 'jsonb_accessor' do
    it 'defines accessor methods for metadata fields' do
      expect(collection).to respond_to(:include_ref_fields)
      expect(collection).to respond_to(:indexing_embedding_versions)
      expect(collection).to respond_to(:search_embedding_version)
      expect(collection).to respond_to(:collection_class)
      expect(collection).to respond_to(:previous_embedding_field)
    end

    it 'persists all accessor values to the metadata column' do
      collection.include_ref_fields = true
      collection.indexing_embedding_versions = [1, 2]
      collection.search_embedding_version = 3
      collection.collection_class = 'MyClass'
      collection.previous_embedding_field = 'prev_embedding'

      collection.save!

      expect(collection.reload.metadata).to include(
        'include_ref_fields' => true,
        'indexing_embedding_versions' => [1, 2],
        'search_embedding_version' => 3,
        'collection_class' => 'MyClass',
        'previous_embedding_field' => 'prev_embedding'
      )
    end
  end

  describe 'embedding model accessor methods' do
    where(:embedding_model) do
      [:current_indexing_embedding_model, :next_indexing_embedding_model, :search_embedding_model]
    end

    with_them do
      context 'with embedding model metadata' do
        before do
          collection.update_metadata!({
            embedding_model => { model_ref: 'model_123', field: 'embeddings_v123' }
          })
        end

        it 'returns the embedding model metadata' do
          model_metadata = collection.public_send(embedding_model)

          expect(model_metadata[:model_ref]).to eq('model_123')
          expect(model_metadata[:field]).to eq('embeddings_v123')
        end
      end

      context 'without embedding model metadata' do
        before do
          collection.update!(metadata: {})
        end

        it 'returns nil' do
          expect(collection.public_send(embedding_model)).to be_nil
        end
      end
    end
  end

  describe '#name_without_prefix' do
    before do
      collection.update!(name: 'documents')
    end

    it 'delegates to the adapter to remove the prefix from the collection name' do
      expect(collection.name_without_prefix)
        .to eq(collection.connection.adapter.collection_name_without_prefix(collection.name))
    end

    it 'returns the name unchanged' do
      expect(collection.name_without_prefix).to eq('documents')
    end
  end
end
