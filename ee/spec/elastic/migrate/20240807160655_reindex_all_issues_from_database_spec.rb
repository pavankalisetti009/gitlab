# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240807160655_reindex_all_issues_from_database.rb')

# See https://docs.gitlab.com/ee/development/testing_guide/best_practices.html#elasticsearch-specs
# for more information on how to write search migration specs for GitLab.
RSpec.describe ReindexAllIssuesFromDatabase, feature_category: :global_search do
  let(:version) { 20240807160655 }

  describe 'migration', :elastic do
    it_behaves_like 'migration reindexes all data' do
      let(:objects) { create_list(:issue, 3) }
      let(:expected_throttle_delay) { 1.minute }
      let(:expected_batch_size) { 50_000 }
    end
  end

  describe '#documents_after_current_id' do
    let(:migration) { described_class.new(version) }
    let_it_be(:project) { create(:project, :public) }
    let_it_be(:issue) { create(:issue, project: project) }
    let_it_be(:issue_epic_type) { create(:issue, :epic) }
    let_it_be(:issue_task_type) { create(:issue, :task) }
    let_it_be(:work_item) { create(:work_item, :epic_with_legacy_epic, :group_level) }
    let_it_be(:non_group_work_item) { create(:work_item) }

    it 'only indexes project-level work_item_type issues' do
      expected_ids = [issue.id, issue_task_type.id, non_group_work_item.id]
      expect(migration.documents_after_current_id.pluck(:id)).to match_array(expected_ids)
    end
  end
end
