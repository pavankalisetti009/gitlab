# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notifications::TargetedMessages::ProcessCsvService, feature_category: :acquisition do
  describe '#execute' do
    let(:service) { described_class.new(csv_file) }
    let(:csv_file) do
      temp_file = Tempfile.new(%w[namespace_ids csv])
      temp_file.write(csv_content)
      temp_file.rewind

      fixture_file_upload(temp_file.path, 'text/csv')
    end

    before_all do
      create(:namespace, id: 1)
      create(:namespace, id: 2)
    end

    subject(:result) { service.execute }

    context 'with valid CSV data' do
      let(:csv_content) do
        <<~CSV
          1
          2
          3
        CSV
      end

      it 'returns valid and invalid namespace ids' do
        expect(result.payload[:valid_namespace_ids]).to contain_exactly(1, 2)
        expect(result.payload[:invalid_namespace_ids]).to contain_exactly(3)
      end
    end

    context 'with empty CSV' do
      let(:csv_content) { '' }

      it 'returns empty arrays' do
        expect(result.payload[:valid_namespace_ids]).to be_empty
        expect(result.payload[:invalid_namespace_ids]).to be_empty
      end
    end

    context 'with invalid data in CSV' do
      let(:csv_content) do
        <<~CSV
          abc
          1
          not_a_number
          2

          3.5
        CSV
      end

      it 'filters out invalid entries and returns valid and invalid namespace ids' do
        expect(result.payload[:valid_namespace_ids]).to contain_exactly(1, 2)
        expect(result.payload[:invalid_namespace_ids]).to be_empty
      end
    end

    context 'with duplicate values' do
      let(:csv_content) do
        <<~CSV
          1
          1
          2
          2
          3
        CSV
      end

      it 'removes duplicates and returns unique valid and invalid namespace ids' do
        expect(result.payload[:valid_namespace_ids]).to contain_exactly(1, 2)
        expect(result.payload[:invalid_namespace_ids]).to contain_exactly(3)
      end
    end

    context 'with a file that cannot be parsed' do
      let(:csv_content) { '"123' }

      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to include('Unclosed quoted field in line 1.')
      end
    end
  end
end
