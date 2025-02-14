# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Collection, feature_category: :global_search do
  subject(:collection) { build(:ai_active_context_collection) }

  it { is_expected.to be_valid }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_length_of(:name).is_at_most(255) }

  it { is_expected.to validate_presence_of(:number_of_partitions) }
  it { is_expected.to validate_numericality_of(:number_of_partitions).is_greater_than_or_equal_to(1).only_integer }

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
end
