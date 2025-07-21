# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250718114546_backfill_milestone_state_work_items_index.rb')

RSpec.describe BackfillMilestoneStateWorkItemsIndex, feature_category: :global_search do
  describe 'migration', :elastic_delete_by_query, :sidekiq_inline do
    include_examples 'migration reindex based on schema_version' do
      let(:version) { 20250718114546 }
      let(:expected_throttle_delay) { 1.minute }
      let(:expected_batch_size) { 10_000 }
      let_it_be(:project) { create(:project) }
      let_it_be(:milestone) do
        create(:milestone, start_date: Time.zone.today, due_date: 1.week.from_now, project: project)
      end

      let(:objects) do
        [create(:work_item, weight: 5, health_status: 1, project: project, milestone: milestone)]
      end
    end
  end
end
