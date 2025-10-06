# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceReport::CsvRow, feature_category: :compliance_management do
  let_it_be(:user) { create(:user, name: 'John Doe') }
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:commit) { project.repository.commit }
  let_it_be(:merged_at_time) { Time.zone.parse('2024-11-18 18:43:20 UTC') }
  let_it_be(:merge_request) do
    create(:merge_request_with_diffs,
      :with_merged_metrics,
      source_project: project,
      target_project: project,
      author: user,
      merge_commit_sha: 'abc123',
      merged_at: merged_at_time)
  end

  let(:from) { 1.week.ago }
  let(:to) { Time.current }
  let(:options) { { merge_request: merge_request } }

  subject(:csv_row) { described_class.new(commit, user, from, to, options) }

  describe '#merged_at' do
    context 'when merge request has merged_at timestamp' do
      it 'returns the merged_at timestamp in ISO 8601 format' do
        expect(csv_row.merged_at).to eq(merged_at_time.xmlschema)
      end

      it 'returns a string in the format YYYY-MM-DDTHH:MM:SS+00:00' do
        expect(csv_row.merged_at).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(Z|[+-]\d{2}:\d{2})/)
      end

      it 'does not return the default Ruby string format' do
        expect(csv_row.merged_at).not_to eq(merged_at_time.to_s)
      end
    end

    context 'when merge request has no merged_at timestamp' do
      let(:merge_request) do
        create(:merge_request_with_diffs,
          source_project: project,
          target_project: project,
          author: user,
          merge_commit_sha: 'abc123')
      end

      it 'returns nil' do
        expect(csv_row.merged_at).to be_nil
      end
    end

    context 'when there is no merge request' do
      let(:options) { {} }

      it 'returns nil' do
        expect(csv_row.merged_at).to be_nil
      end
    end
  end

  describe '#committed_at' do
    it 'returns the commit timestamp (for comparison with merged_at format)' do
      expect(csv_row.committed_at).to eq(commit.timestamp)
    end

    it 'returns a timestamp in ISO 8601 format' do
      expect(csv_row.committed_at).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(Z|[+-]\d{2}:\d{2})/)
    end
  end

  describe 'date format consistency' do
    it 'ensures both committed_at and merged_at use the same date format structure' do
      committed_format = csv_row.committed_at
      merged_format = csv_row.merged_at

      # Both should match ISO 8601 format pattern
      iso_pattern = /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(Z|[+-]\d{2}:\d{2})/
      expect(committed_format).to match(iso_pattern)
      expect(merged_format).to match(iso_pattern)
    end
  end
end
