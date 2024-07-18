# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240716141532_reindex_merge_requests_to_backfill_label_ids.rb')

RSpec.describe ReindexMergeRequestsToBackfillLabelIds, :elastic_delete_by_query, :sidekiq_inline, feature_category: :global_search do
  let(:version) { 20240716141532 }

  include_examples 'migration reindex based on schema_version' do
    let(:objects) { create_list(:merge_request, 3) }
    let(:expected_throttle_delay) { 1.minute }
    let(:expected_batch_size) { 9_000 }
  end
end
