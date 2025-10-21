# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Settings > Issues', :js, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:maintainer) { create(:user, maintainer_of: [group, subgroup]) }
  let_it_be(:developer) { create(:user, developer_of: [group, subgroup]) }
  let(:user) { maintainer }

  before do
    stub_licensed_features(work_item_status: true)
  end

  shared_examples 'prevents access' do
    it 'returns 404' do
      sign_in(user)
      visit group_settings_issues_path(target_group)

      expect(page).to have_content('404: Page not found')
    end
  end

  context 'with root group' do
    let(:target_group) { group }

    context 'when user is authorized' do
      before do
        sign_in(user)
        visit group_settings_issues_path(target_group)
      end

      it 'can add statuses' do
        click_button('Edit statuses')
        within_testid('category-triage') do
          click_button('Add status')
          fill_in 'Name', with: 'Triage custom status'
          click_button('Add description')
          fill_in 'Description', with: 'Deciding what to do with things'
          click_button('Save')
        end

        click_button('Edit statuses')
        within_testid('category-to_do') do
          click_button('Add status')
          fill_in 'Name', with: 'To do custom status'
          click_button('Add description')
          fill_in 'Description', with: 'Things to do'
          click_button('Save')
        end

        within_testid('category-in_progress') do
          click_button('Add status')
          fill_in 'Name', with: 'In progress custom status'
          click_button('Add description')
          fill_in 'Description', with: 'Things in progress'
          click_button('Save')
        end

        within_testid('category-done') do
          click_button('Add status')
          fill_in 'Name', with: 'Done custom status'
          click_button('Add description')
          fill_in 'Description', with: 'Things done'
          click_button('Save')
        end

        within_testid('category-canceled') do
          click_button('Add status')
          fill_in 'Name', with: 'Canceled custom status'
          click_button('Add description')
          fill_in 'Description', with: 'Things canceled'
          click_button('Save')
        end

        within_testid('lifecycle-detail') do
          expect(page).to have_text('Triage custom status')
          expect(page).to have_text('To do custom status')
          expect(page).to have_text('In progress custom status')
          expect(page).to have_text('Done custom status')
          expect(page).to have_text('Canceled custom status')
        end
      end

      it 'can edit and remove statuses' do
        click_button('Edit statuses')
        within_testid('category-triage') do
          click_button('Add status')
          fill_in 'Name', with: 'Edit me'
          click_button('Add description')
          fill_in 'Description', with: 'Change is inevitable'
          click_button('Save')
        end

        within_testid('lifecycle-detail') do
          expect(page).to have_text('Edit me')
        end

        click_button('Edit statuses')
        within_testid('category-triage') do
          click_button('More actions')
          click_button('Edit status')
          fill_in 'Name', with: 'Delete me'
          click_button('Update')
        end
        click_button('Close', match: :first)

        within_testid('lifecycle-detail') do
          expect(page).not_to have_text('Edit me')
          expect(page).to have_text('Delete me')
        end

        click_button('Edit statuses')
        within_testid('category-triage') do
          click_button('More actions')
          click_button('Remove status')
        end
        click_button('Remove')
        click_button('Close', match: :first)

        within_testid('lifecycle-detail') do
          expect(page).not_to have_text('Edit me')
          expect(page).not_to have_text('Delete me')
        end
      end
    end

    context 'when user is not authorized' do
      it_behaves_like 'prevents access' do
        let(:user) { developer }
      end
    end

    context 'without the licensed feature' do
      before do
        stub_licensed_features(work_item_status: false)
      end

      it_behaves_like 'prevents access'
    end
  end

  context 'with subgroup' do
    let(:target_group) { subgroup }

    it_behaves_like 'prevents access'

    context 'without the licensed feature' do
      before do
        stub_licensed_features(work_item_status: false)
      end

      it_behaves_like 'prevents access'
    end
  end
end
