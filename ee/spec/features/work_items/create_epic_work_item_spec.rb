# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create work item epic', :js, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public) }

  before_all do
    group.add_owner(user)
    group.add_maintainer(user)
    group.add_developer(user)
  end

  context 'when we click on new epic' do
    before do
      stub_licensed_features(epics: true, subepics: true, issuable_health_status: true, epic_colors: true)
      sign_in(user)
      visit group_work_items_path(group)
      click_link 'New epic'
    end

    it 'shows the modal' do
      expect(page).to have_selector('[id="create-work-item-modal"]')
    end

    it 'has the expected widgets', :aggregate_failures do
      expect(page).to have_selector('[data-testid="work-item-description-wrapper"]')
      expect(page).to have_selector('[data-testid="work-item-assignees"]')
      expect(page).to have_selector('[data-testid="work-item-labels"]')
      expect(page).to have_selector('[data-testid="work-item-rolledup-dates"]')
      expect(page).to have_selector('[data-testid="work-item-health-status"]')
      expect(page).to have_selector('[data-testid="work-item-color"]')
    end
  end
end
