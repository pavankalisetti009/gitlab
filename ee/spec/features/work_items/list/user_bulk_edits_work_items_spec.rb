# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Work items bulk editing', :js, feature_category: :team_planning do
  include WorkItemsHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:bug_label) { create(:group_label, group: group, title: 'bug') }
  let_it_be(:feature_label) { create(:group_label, group: group, title: 'feature') }
  let_it_be(:frontend_label) { create(:group_label, group: group, title: 'frontend') }
  let_it_be(:wontfix_label) { create(:group_label, group: group, title: 'wontfix') }
  let_it_be(:epic) { create(:work_item, :epic, namespace: group, title: "Epic without label") }
  let_it_be(:issue) { create(:work_item, :issue, project: project, title: "Issue without label") }
  let_it_be(:epic_with_label) do
    create(:work_item, :epic, namespace: group, title: "Epic with label", labels: [frontend_label])
  end

  let_it_be(:epic_with_multiple_labels) do
    create(:work_item, :epic, namespace: group, title: "Epic with multiple labels",
      labels: [frontend_label, wontfix_label, feature_label])
  end

  before_all do
    group.add_developer(user)
  end

  before do
    sign_in user
    stub_licensed_features(epics: true, group_bulk_edit: true)
  end

  context 'when user is signed in' do
    context 'when bulk editing labels on group work items' do
      before do
        visit group_work_items_path(group)
        click_bulk_edit
      end

      it_behaves_like 'when user bulk assigns labels' do
        let(:work_item) { epic }
        let(:work_item_with_label) { epic_with_label }
      end

      it_behaves_like 'when user bulk assign labels on mixed work item types' do
        let(:work_item) { epic }
        let(:work_item_2) { issue }
      end

      it_behaves_like 'when user bulk unassigns labels' do
        let(:work_item_with_label) { epic_with_label }
        let(:work_item_with_multiple_labels) { epic_with_multiple_labels }
      end

      it_behaves_like 'when user bulk assigns and unassigns labels simultaneously' do
        let(:work_item) { epic }
        let(:work_item_with_label) { epic_with_label }
      end
    end

    context 'when bulk editing labels on group epics list' do
      before do
        stub_feature_flags(work_item_planning_view: false)
        visit group_epics_path(group)
        click_bulk_edit
      end

      it_behaves_like 'when user bulk assigns labels' do
        let(:work_item) { epic }
        let(:work_item_with_label) { epic_with_label }
      end

      it_behaves_like 'when user bulk unassigns labels' do
        let(:work_item_with_label) { epic_with_label }
        let(:work_item_with_multiple_labels) { epic_with_multiple_labels }
      end

      it_behaves_like 'when user bulk assigns and unassigns labels simultaneously' do
        let(:work_item) { epic }
        let(:work_item_with_label) { epic_with_label }
      end
    end
  end
end
