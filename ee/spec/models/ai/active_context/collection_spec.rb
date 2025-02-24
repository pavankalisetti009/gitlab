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

    it 'is invalid when not empty' do
      collection.metadata = { key: 'value' }
      expect(collection).not_to be_valid
      expect(collection.errors[:metadata]).to include('must be a valid json schema')
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
end
