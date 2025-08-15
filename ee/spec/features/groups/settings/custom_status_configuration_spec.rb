# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Settings > Work items', :js, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:maintainer) { create(:user, maintainer_of: [group, subgroup]) }
  let_it_be(:developer) { create(:user, developer_of: [group, subgroup]) }

  before do
    stub_licensed_features(work_item_status: true)
    sign_in(maintainer)
  end

  context 'with root group' do
    context 'when user is authorized' do
      it 'allows to configure statuses' do
        visit group_settings_issues_path(group)

        click_button('Edit statuses')

        within_testid('category-triage') do
          click_button('Add status')
          fill_in 'status-name', with: 'Triage custom status'
          click_button('Add description')
          fill_in 'status-description', with: 'Deciding what to do with things'
          click_button('Save')
        end

        wait_for_requests

        expect(page).to have_content('Triage custom status')
      end
    end

    context 'when user is not authorized' do
      before do
        sign_in(developer)
      end

      it 'returns 404' do
        visit group_settings_issues_path(subgroup)

        expect(page).to have_content('404: Page not found')
      end
    end
  end

  context 'with subgroup' do
    it 'returns 404' do
      visit group_settings_issues_path(subgroup)

      expect(page).to have_content('404: Page not found')
    end
  end
end
