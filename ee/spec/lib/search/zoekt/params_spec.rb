# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Params, feature_category: :global_search do
  let(:multi_match_double) { instance_double(Search::Zoekt::MultiMatch, max_chunks_size: 42) }

  describe '#max_file_match_window' do
    it 'returns UNLIMITED' do
      params = described_class.new(limit: 10)
      expect(params.max_file_match_window).to eq(Search::Zoekt::Params::UNLIMITED)
    end
  end

  describe '#max_file_match_results' do
    it 'returns search_limit when multi_match is present' do
      params = described_class.new(limit: 10, multi_match: multi_match_double)
      expect(params.max_file_match_results).to eq(10)
    end

    it 'returns UNLIMITED when multi_match is not present' do
      params = described_class.new(limit: 10)
      expect(params.max_file_match_results).to eq(Search::Zoekt::Params::UNLIMITED)
    end
  end

  describe '#max_line_match_window' do
    it 'returns ZOEKT_COUNT_LIMIT' do
      stub_const('Search::Zoekt::SearchResults::ZOEKT_COUNT_LIMIT', 123)
      params = described_class.new(limit: 10)
      expect(params.max_line_match_window).to eq(123)
    end
  end

  describe '#max_line_match_results' do
    it 'returns 0 when multi_match is present' do
      params = described_class.new(limit: 10, multi_match: multi_match_double)
      expect(params.max_line_match_results).to eq(0)
    end

    it 'returns search_limit when multi_match is not present' do
      params = described_class.new(limit: 10)
      expect(params.max_line_match_results).to eq(10)
    end
  end

  describe '#max_line_match_results_per_file' do
    context 'when multi_match is passed' do
      it 'factors the max_chunks_size passed in the multi_match' do
        result = described_class.new(limit: 10, multi_match: multi_match_double).max_line_match_results_per_file
        expect(result).to eq(multi_match_double.max_chunks_size * described_class::LINE_MATCHES_FACTOR)
      end
    end

    context 'when multi_match is not passed' do
      it 'factors the MAX_CHUNKS_PER_FILE' do
        result = described_class.new(limit: 10).max_line_match_results_per_file
        expect(result).to eq(Search::Zoekt::MultiMatch::MAX_CHUNKS_PER_FILE * described_class::LINE_MATCHES_FACTOR)
      end
    end
  end
end
