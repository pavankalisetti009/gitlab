# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20251021114546_reindex_labels_in_work_items.rb')

RSpec.describe ReindexLabelsInWorkItems, feature_category: :global_search do
  describe 'migration', :elastic_delete_by_query, :sidekiq_inline do
    include_examples 'migration reindex based on schema_version' do
      let(:version) { 20251021114546 }
      let(:expected_throttle_delay) { 15.seconds }
      let(:expected_batch_size) { 10_000 }
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, group: group) }
      let_it_be(:label) { create(:label, project: project) }
      let_it_be(:group_label) { create(:group_label, group: group) }

      let(:objects) do
        [
          create(:work_item, project: project, labels: [label]),
          create(:work_item, :epic, namespace: group, labels: [group_label])
        ]
      end
    end
  end
end
