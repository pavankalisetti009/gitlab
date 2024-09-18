# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Work item hierarchy', :js, feature_category: :portfolio_management do
  include DragTo

  let_it_be(:organization) { create(:organization) }
  let(:user) { create(:user, name: 'Sherlock Holmes') }
  let(:group) { create(:group, :public, organization: organization) }
  let(:epic) { create(:work_item, :epic_with_legacy_epic, namespace: group) }

  before do
    group.add_developer(user)

    sign_in(user)

    stub_licensed_features(epics: true, subepics: true)
    stub_feature_flags(work_items: true, work_item_epics: true, work_item_epics_rollout: true)
  end

  context 'in epic hierarchy tree' do
    before do
      visit group_work_item_path(group, epic.iid)
    end

    it 'reorders children', :aggregate_failures do
      # https://gitlab.com/gitlab-org/gitlab/-/issues/467207
      allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(300)

      create_work_item('epic', 'Epic 1')
      create_work_item('epic', 'Epic 2')
      create_work_item('epic', 'Epic 3')

      expect(page).to have_css('.tree-item:nth-child(1) .item-title', text: 'Epic 3')
      expect(page).to have_css('.tree-item:nth-child(2) .item-title', text: 'Epic 2')
      expect(page).to have_css('.tree-item:nth-child(3) .item-title', text: 'Epic 1')

      drag_to(selector: '.sortable-container', from_index: 0, to_index: 2)

      expect(page).to have_css('.tree-item:nth-child(1) .item-title', text: 'Epic 2')
      expect(page).to have_css('.tree-item:nth-child(2) .item-title', text: 'Epic 1')
      expect(page).to have_css('.tree-item:nth-child(3) .item-title', text: 'Epic 3')
    end
  end

  describe 'nested children' do
    let(:child1) { create(:work_item, :epic_with_legacy_epic, namespace: group, title: 'Child 1') }
    let(:child2) { create(:work_item, :epic_with_legacy_epic, namespace: group, title: 'Child 2') }
    let(:child1a) { create(:work_item, :epic_with_legacy_epic, namespace: group, title: 'Child a') }

    before do
      create(:parent_link, work_item_parent: epic, work_item: child1)
      create(:parent_link, work_item_parent: epic, work_item: child2)
      create(:parent_link, work_item_parent: child1, work_item: child1a)

      visit group_work_item_path(group, epic.iid)
    end

    it 'can be expanded' do
      expect(page).to have_css('.tree-item .item-title', text: 'Child 1')
      expect(page).to have_css('.tree-item .item-title', text: 'Child 2')

      expect(page).not_to have_css('.tree-item .item-title', text: 'Child a')

      click_button('Expand', match: :first)
      wait_for_all_requests

      expect(page).to have_css('.tree-item .item-title', text: 'Child a')
    end
  end

  def create_work_item(type, title)
    wait_for_all_requests

    within_testid('work-item-tree') do
      click_button 'Add'
      click_button "New #{type}"
      wait_for_all_requests # wait for work items type to load

      fill_in 'Add a title', with: title

      click_button "Create #{type}"

      wait_for_all_requests
    end
  end
end
