# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Epic boards sidebar', :js, feature_category: :portfolio_management do
  include BoardHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:epic_board) { create(:epic_board, group: group) }
  let_it_be(:backlog_list) { create(:epic_list, epic_board: epic_board, list_type: :backlog) }
  let_it_be(:closed_list) { create(:epic_list, epic_board: epic_board, list_type: :closed) }
  let_it_be(:epic) { create(:epic, group: group, title: 'Epic1') }

  let(:card) { find('[data-testid="board-list"]:nth-child(1)').first("[data-testid='board-card']") }

  before do
    stub_feature_flags(work_item_view_for_issues: true)
    stub_licensed_features(epics: true)
    group.add_maintainer(user)
    sign_in(user)
    visit group_epic_boards_path(group)
  end

  it 'shows and closes work item drawer when clicking epic and close button' do
    click_card(card)

    expect(page).to have_testid('work-item-drawer')
    expect(page).to have_css('h2', text: epic.title)

    click_card(card)

    expect(page).not_to have_testid('work-item-drawer')

    click_card(card)

    expect(page).to have_testid('work-item-drawer')

    if Users::ProjectStudio.enabled_for_user?(user) # rubocop:disable RSpec/AvoidConditionalStatements -- temporary Project Studio rollout
      click_button 'Close panel'
    else
      click_button 'Close drawer'
    end

    expect(page).not_to have_testid('work-item-drawer')
  end

  context 'title' do
    it 'edits epic title' do
      click_card(card)

      within_testid('work-item-drawer') do
        click_button 'Edit', match: :first
        fill_in 'Title', with: 'Test title'
        click_button 'Save changes'

        expect(page).to have_css('h2', text: 'Test title')
      end

      expect(card).to have_content('Test title')
    end
  end

  context 'todo' do
    it 'creates todo when clicking button' do
      click_card(card)

      within_testid('work-item-drawer') do
        click_button 'Add a to-do item'

        expect(page).to have_button('Mark as done')
      end
    end

    it 'marks a todo as done' do
      click_card(card)

      within_testid('work-item-drawer') do
        click_button 'Add a to-do item'
        click_button 'Mark as done'

        expect(page).to have_button 'Add a to-do item'
      end
    end
  end

  context 'dates' do
    before do
      click_card(card)
    end

    it_behaves_like 'work items due dates in drawer'
  end

  context 'confidentiality' do
    it 'make epic confidential' do
      click_card(card)

      within_testid('work-item-drawer') do
        click_button 'More actions', match: :first
        click_button 'Turn on confidentiality'

        expect(page).to have_css('.gl-badge', text: 'Confidential')
      end
    end
  end

  context 'in notifications subscription' do
    it 'shows toggle as on then as off as user toggles to subscribe and unsubscribe', :aggregate_failures do
      click_card(card)

      within_testid('work-item-drawer') do
        click_button 'More actions', match: :first

        expect(page).to have_button('Notifications')
        expect(page).to have_css('button[role="switch"][aria-checked="false"]')

        click_button('Notifications')

        expect(page).to have_css('button[role="switch"][aria-checked="true"]')

        click_button('Notifications')

        expect(page).to have_css('button[role="switch"][aria-checked="false"]')
      end
    end
  end
end
