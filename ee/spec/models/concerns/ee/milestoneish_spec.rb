# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Milestoneish, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be(:parent_group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: parent_group) }
  let_it_be(:project) { create(:project, :empty_repo, namespace: parent_group) }
  let_it_be(:sub_group_project) { create(:project, :empty_repo, namespace: sub_group) }
  let_it_be(:milestone) { create(:milestone, group: parent_group) }

  let_it_be(:sub_group_work_item_epic) do
    create(:work_item, :epic, :group_level, namespace: sub_group, milestone: milestone)
  end

  let_it_be(:parent_group_work_item_epic) do
    create(:work_item, :epic, :group_level, namespace: parent_group, milestone: milestone)
  end

  let_it_be(:issue) { create(:work_item, milestone: milestone, project: project) }

  before_all do
    parent_group.add_developer(user)
  end

  describe '#sorted_issues' do
    context 'when work_items_alpha feature flag is disabled' do
      before do
        stub_feature_flags(work_items_alpha: false)
      end

      it 'excludes epic work items from return results' do
        items = milestone.sorted_issues(user)
        expect(items.length).to eq(1)
        expect(items.first).to eq(issue)
      end
    end

    context 'when work_items_alpha feature flag is enabled' do
      it 'includes epic work items in return results' do
        items = milestone.sorted_issues(user)
        expect(items.first).to eq(issue)
        expect(items.second).to eq(parent_group_work_item_epic)
        expect(items.third).to eq(sub_group_work_item_epic)
      end
    end
  end
end
