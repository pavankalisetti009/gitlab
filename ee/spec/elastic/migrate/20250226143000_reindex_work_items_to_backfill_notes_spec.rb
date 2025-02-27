# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250226143000_reindex_work_items_to_backfill_notes.rb')

RSpec.describe ReindexWorkItemsToBackfillNotes, :elastic_delete_by_query, :sidekiq_inline, feature_category: :global_search do
  let(:version) { 20250226143000 }

  describe 'skip_if setting' do
    subject(:migration) { described_class.new(version) }

    context 'when on Saas', :saas do
      it { expect(migration.skip_migration?).to be false }
    end

    context 'when not on Saas' do
      it { expect(migration.skip_migration?).to be true }
    end
  end

  include_examples 'migration reindex based on schema_version' do
    let(:index_name) { ::Search::Elastic::Types::WorkItem.index_name }
    let(:objects) { create_list(:work_item, 3) }
    let(:expected_throttle_delay) { 1.minute }
    let(:expected_batch_size) { 9_000 }
  end
end
