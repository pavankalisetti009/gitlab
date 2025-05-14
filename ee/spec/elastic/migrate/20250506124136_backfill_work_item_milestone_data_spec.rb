# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250506124136_backfill_work_item_milestone_data.rb')

RSpec.describe BackfillWorkItemMilestoneData, feature_category: :global_search do
  let(:version) { 20250506124136 }

  describe 'migration', :elastic_delete_by_query, :sidekiq_inline do
    include_examples 'migration backfills fields' do
      let(:expected_throttle_delay) { 1.minute }
      let(:expected_batch_size) { 1000 }

      let_it_be(:project) { create(:project) }
      let_it_be(:milestone) { create(:milestone, project: project) }

      let(:objects) { create_list(:work_item, 3, project: project, milestone: milestone) }

      let(:expected_fields) do
        { milestone_id: milestone.id, milestone_title: milestone.title }
      end
    end
  end
end
