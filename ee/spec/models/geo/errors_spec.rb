# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::Errors, :geo, type: :model, feature_category: :geo_replication do
  RSpec.shared_examples 'logs warning on initialization' do
    it 'logs a warning when initialized' do
      expect(Gitlab::Geo::Logger).to receive(:warn).with(hash_including(expected_log_data))

      error
    end
  end

  describe 'StatusTimeoutError' do
    subject(:error) { described_class::StatusTimeoutError.new }

    it 'returns the correct error message' do
      expect(error.message).to eq('Generating Geo node status is taking too long')
    end
  end

  describe 'ReplicableExcludedFromVerificationError' do
    subject(:error) do
      described_class::ReplicableExcludedFromVerificationError.new(
        model_class: 'Upload',
        model_record_id: 123
      )
    end

    let(:expected_log_data) do
      {
        message: 'File is not checksummable because the replicable is excluded from verification',
        model_class: 'Upload',
        model_record_id: 123
      }
    end

    it_behaves_like 'logs warning on initialization'

    it 'returns the correct error message' do
      expect(error.message).to eq('File is not checksummable - Upload 123 is excluded from verification')
    end

    it 'stores the model class' do
      expect(error.model_class).to eq('Upload')
    end

    it 'stores the model record id' do
      expect(error.model_record_id).to eq(123)
    end
  end

  describe 'ReplicableDoesNotExistError' do
    subject(:error) do
      described_class::ReplicableDoesNotExistError.new(
        file_path: '/path/to/missing/file.txt'
      )
    end

    let(:expected_log_data) do
      {
        message: 'File is not checksummable because it does not exist',
        file_path: '/path/to/missing/file.txt'
      }
    end

    it_behaves_like 'logs warning on initialization'

    it 'returns the correct error message' do
      expect(error.message).to eq("File is not checksummable - file does not exist at: /path/to/missing/file.txt")
    end

    it 'stores the file path' do
      expect(error.file_path).to eq('/path/to/missing/file.txt')
    end
  end

  describe 'MessageWithFilePath' do
    describe '.build' do
      let(:prefix) { "Error message prefix: " }

      context 'when file path fits within max length' do
        let(:file_path) { '/short/path/file.txt' }

        it 'returns the full message without truncation' do
          result = described_class::MessageWithFilePath.build(prefix: prefix, file_path: file_path)

          expect(result).to eq("#{prefix}#{file_path}")
          expect(result.length).to be <= 255
        end
      end

      context 'when file path exceeds max length' do
        let(:long_path) { "/very/long/path/#{'nested/directory/' * 20}some_file_with_a_long_name.txt" }

        it 'truncates the path from the beginning' do
          result = described_class::MessageWithFilePath.build(prefix: prefix, file_path: long_path)

          expect(result).to start_with(prefix)
          expect(result).to end_with('some_file_with_a_long_name.txt')
          expect(result.length).to be <= 255
        end

        it 'preserves the end of the path' do
          result = described_class::MessageWithFilePath.build(prefix: prefix, file_path: long_path)

          expect(result).to include('some_file_with_a_long_name.txt')
        end
      end

      context 'when file path is exactly at the limit' do
        let(:max_path_length) { 255 - prefix.length }
        let(:exact_path) { 'a' * max_path_length }

        it 'returns the full path without truncation' do
          result = described_class::MessageWithFilePath.build(prefix: prefix, file_path: exact_path)

          expect(result).to eq("#{prefix}#{exact_path}")
          expect(result.length).to eq(255)
        end
      end

      context 'when file path is one character over the limit' do
        let(:max_path_length) { 255 - prefix.length }
        let(:over_limit_path) { 'a' * (max_path_length + 1) }

        it 'truncates by one character' do
          result = described_class::MessageWithFilePath.build(prefix: prefix, file_path: over_limit_path)

          expect(result.length).to eq(255)
          expect(result).to start_with(prefix)
        end
      end

      context 'when file path is nil' do
        it 'handles nil gracefully' do
          result = described_class::MessageWithFilePath.build(prefix: prefix, file_path: nil)

          expect(result).to eq("#{prefix}(path unavailable)")
        end
      end
    end
  end
end
