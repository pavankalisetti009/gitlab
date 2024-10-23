# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create issuable work item', :js, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public) }

  before_all do
    project.add_owner(user)
    project.add_maintainer(user)
    project.add_developer(user)
  end

  context 'when we go to new work item path in project and select issue from dropdown' do
    before do
      stub_licensed_features(issuable_health_status: true, iterations: true)
      sign_in(user)
      wait_for_all_requests
      visit "#{project_path(project)}/-/work_items/new"
      wait_for_all_requests
      button_toggle_dropdown = find_by_testid('work-item-types-select')

      button_toggle_dropdown.click
      button_toggle_dropdown.select('Issue')
      wait_for_requests
    end

    it 'has the expected `ee` widgets', :aggregate_failures do
      expect(page).to have_selector('[data-testid="work-item-health-status"]')
      expect(page).to have_selector('[data-testid="work-item-iteration"]')
    end
  end
end
