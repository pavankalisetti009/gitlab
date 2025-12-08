# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Settings > Issues - lifecycles', :js, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, owners: user) }

  before do
    stub_licensed_features(work_item_status: true)
  end

  shared_examples 'lifecycle management' do
    it 'creates lifecycles based on previous ones, and deletes lifecycles', :aggregate_failures do
      sign_in(user)
      visit settings_path

      click_button 'Create lifecycle'
      fill_in 'Lifecycle name', with: 'Lifecycle Alpha'
      click_button 'Create'

      within('#status-modal') do
        expect(page).to have_testid('lifecycle-info', text: 'Lifecycle: Lifecycle Alpha')

        within_testid('category-to_do') do
          click_button('Add status')
          fill_in 'Name', with: 'To do alpha'
          click_button('Save')
        end
        click_button 'Close', match: :first
      end

      click_button 'Create lifecycle'
      fill_in 'Lifecycle name', with: 'Lifecycle Beta'
      fill_in 'Search lifecycles', with: 'Alpha'
      choose 'Lifecycle Alpha'
      click_button 'Create'

      within('#status-modal') do
        expect(page).to have_testid('lifecycle-info', text: 'Lifecycle: Lifecycle Beta')

        within_testid('category-to_do') do
          expect(page).to have_testid('status-badge', text: 'To do alpha')
        end

        click_button 'Close', match: :first
      end

      expect(page).to have_testid('lifecycle-detail', text: 'Lifecycle Alpha')
      expect(page).to have_testid('lifecycle-detail', text: 'Lifecycle Beta')

      click_button 'Remove lifecycle', match: :first
      click_button 'Remove' # Click "Remove" in confirmation modal

      expect(page).to have_testid('lifecycle-detail', text: 'Lifecycle Alpha')
      expect(page).not_to have_testid('lifecycle-detail', text: 'Lifecycle Beta')
    end
  end

  context 'when work_item_planning_view FF is disabled' do
    let(:settings_path) { group_settings_issues_path(group, anchor: 'js-custom-status-settings') }

    before do
      stub_feature_flags(work_item_planning_view: false)
    end

    it_behaves_like 'lifecycle management'
  end

  context 'when work_item_planning_view FF is enabled' do
    let(:settings_path) { group_settings_work_items_path(group, anchor: 'js-custom-status-settings') }

    before do
      stub_feature_flags(work_item_planning_view: true)
    end

    it_behaves_like 'lifecycle management'
  end
end
