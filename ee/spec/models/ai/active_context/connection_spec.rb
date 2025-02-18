# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Connection, feature_category: :global_search do
  describe 'validations' do
    subject { build(:ai_active_context_connection) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:adapter_class) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:adapter_class).is_at_most(255) }
    it { is_expected.to validate_length_of(:prefix).is_at_most(255) }

    describe 'options validation' do
      let(:connection) { build(:ai_active_context_connection) }

      it 'validates options is valid hash' do
        connection.options = { key: 'value' }
        expect(connection).to be_valid

        connection.options = 'not a hash'
        expect(connection).not_to be_valid
        expect(connection.errors[:options]).to include('must be a hash')

        connection.options = { key: :value }
        expect(connection).to be_valid
      end
    end
  end

  describe 'encryption' do
    it 'encrypts options' do
      connection = create(:ai_active_context_connection)
      saved_connection = described_class.find(connection.id)

      # The encrypted value should be different from the original
      expect(saved_connection.options['token']).to eq(connection.options['token'])
      expect(saved_connection.attributes['options']).not_to include(connection.options['token'])
    end
  end

  describe 'scopes' do
    describe '.active' do
      let!(:active_connection) { create(:ai_active_context_connection) }
      let!(:inactive_connection) { create(:ai_active_context_connection, :inactive) }

      it 'returns only active connections' do
        expect(described_class.active).to contain_exactly(active_connection)
      end
    end
  end
end
