# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20241202154404_reindex_work_items_to_contain_notes.rb')

RSpec.describe ReindexWorkItemsToContainNotes, :elastic_delete_by_query, :sidekiq_inline, feature_category: :global_search do
  let(:version) { 20241202154404 }

  include_examples 'migration reindex based on schema_version' do
    let(:index_name) { ::Search::Elastic::Types::WorkItem.index_name }
    let(:objects) { create_list(:work_item, 3) }
    let(:expected_throttle_delay) { 1.minute }
    let(:expected_batch_size) { 9_000 }
  end
end
