# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group issues page', feature_category: :team_planning do
  let(:group) { create(:group) }
  let(:project) { create(:project, :public, group: group) }

  context 'bulk editing', :js do
    let(:user_in_group) { create(:group_member, :maintainer, user: create(:user), group: group).user }
    let!(:milestone) { create(:milestone, group: group) }
    let!(:issue) { create(:work_item, :issue, title: 'My Work Item', project: project) }

    before do
      sign_in(user_in_group)
      visit issues_group_path(group)
    end

    it 'shows sidebar when clicked on "Bulk edit"' do
      click_button 'Bulk edit'

      expect(page).to have_selector('.issues-bulk-update.right-sidebar-expanded', visible: true)

      page.within('.issues-bulk-update') do
        expect(page).to have_selector('form#work-item-list-bulk-edit')
      end
    end

    it 'shows group milestones within "Milestone" dropdown' do
      click_button 'Bulk edit'

      check 'Select all'

      click_button 'Select milestone'

      wait_for_all_requests

      page.within('.gl-new-dropdown-panel', visible: true) do
        expect(page).to have_selector('li[role="option"]', text: milestone.title)
      end
    end
  end
end
