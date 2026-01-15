# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20251204143000_backfill_traversal_ids_for_milestones.rb')

RSpec.describe BackfillTraversalIdsForMilestones, :elastic_delete_by_query, :sidekiq_inline,
  feature_category: :global_search do
  include_examples 'migration backfills fields' do
    let_it_be(:project) { create(:project) }
    let(:version) { 20251204143000 }
    let(:expected_throttle_delay) { 1.minute }
    let(:expected_batch_size) { 9000 }
    let(:objects) { create_list(:milestone, 3, project: project) }
    let(:expected_fields) { { traversal_ids: project.elastic_namespace_ancestry } }
  end
end
