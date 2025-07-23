# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Work items list filters', :js, feature_category: :team_planning do
  include FilteredSearchHelpers

  let_it_be(:user) { create(:user) }

  let_it_be(:group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: group) }
  let_it_be(:sub_group_project) { create(:project, :public, group: sub_group, developers: user) }
  let_it_be(:sub_sub_group) { create(:group, parent: sub_group) }
  let_it_be(:project) { create(:project, :public, group: group, developers: user) }

  let_it_be(:epic) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
  let_it_be(:sub_epic) { create(:work_item, :epic_with_legacy_epic, namespace: sub_group) }
  let_it_be(:sub_issue) { create(:issue, project: sub_group_project) }
  let_it_be(:sub_sub_epic) { create(:work_item, :epic_with_legacy_epic, namespace: sub_sub_group) }

  let_it_be(:incident) { create(:incident, project: project) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:task) { create(:work_item, :task, project: project) }
  let_it_be(:test_case) { create(:quality_test_case, project: project) }

  let_it_be(:weighted_issue_1) { create(:issue, project: project, weight: 1) }
  let_it_be(:weighted_issue_2) { create(:issue, project: project, weight: 2) }
  let_it_be(:weighted_issue_5) { create(:issue, project: project, weight: 5) }
  let_it_be(:unweighted_issue) { create(:issue, project: project, weight: nil) }

  def expect_work_items_list_count(count)
    expect(page).to have_css('.issue', count: count)
  end

  context 'for signed in user' do
    before do
      stub_licensed_features(epics: true, quality_management: true, subepics: true, issue_weights: true)
      sign_in(user)
      visit group_work_items_path(group)
    end

    describe 'group' do
      it 'filters', :aggregate_failures, quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/523412' do
        select_tokens 'Group', group.name, submit: true

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_link(epic.title)

        click_button 'Clear'

        select_tokens 'Group', sub_group.name, submit: true

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_link(sub_epic.title)

        click_button 'Clear'

        select_tokens 'Group', sub_sub_group.name, submit: true

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_link(sub_sub_epic.title)
      end
    end

    describe 'type' do
      it 'filters', :aggregate_failures do
        select_tokens('Type', '=', 'Issue', submit: true)

        expect(page).to have_css('.issue', count: 6)
        expect(page).to have_link(issue.title)
        expect(page).to have_link(sub_issue.title)

        click_button 'Clear'

        select_tokens('Type', '=', 'Inciden', submit: true)

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_link(incident.title)

        click_button 'Clear'

        select_tokens('Type', '=', 'Test case', submit: true)

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_link(test_case.title)

        click_button 'Clear'

        select_tokens('Type', '=', 'Task', submit: true)

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_link(task.title)
      end
    end

    describe 'weight' do
      before do
        visit project_work_items_path(project)
      end

      describe 'behavior' do
        it 'loads all the weights when opened' do
          select_tokens 'Weight', '='

          # Expect None, Any, numbers 0 to 20
          expect_suggestion_count 23
        end
      end

      describe 'only weight' do
        it 'filters work items by searched weight' do
          select_tokens 'Weight', '=', '1', submit: true

          expect_work_items_list_count(1)
          expect(page).to have_link(weighted_issue_1.title)
        end

        it 'filters work items by weight 2' do
          select_tokens 'Weight', '=', '2', submit: true

          expect_work_items_list_count(1)
          expect(page).to have_link(weighted_issue_2.title)
        end

        it 'filters work items by weight 5' do
          select_tokens 'Weight', '=', '5', submit: true

          expect_work_items_list_count(1)
          expect(page).to have_link(weighted_issue_5.title)
        end
      end

      describe 'weight wildcards' do
        it 'filters work items by None weight' do
          select_tokens 'Weight', '=', 'None', submit: true

          expect(page).to have_link(unweighted_issue.title)
          expect(page).not_to have_link(weighted_issue_1.title)
          expect(page).not_to have_link(weighted_issue_2.title)
          expect(page).not_to have_link(weighted_issue_5.title)
        end

        it 'filters work items by Any weight' do
          select_tokens 'Weight', '=', 'Any', submit: true

          expect_work_items_list_count(3)
          expect(page).to have_link(weighted_issue_1.title)
          expect(page).to have_link(weighted_issue_2.title)
          expect(page).to have_link(weighted_issue_5.title)
          expect(page).not_to have_link(unweighted_issue.title)
        end
      end

      describe 'negated weight only' do
        it 'excludes work items with specified weight' do
          select_tokens 'Weight', '!=', '2', submit: true

          expect(page).to have_link(weighted_issue_1.title)
          expect(page).to have_link(weighted_issue_5.title)
          expect(page).to have_link(unweighted_issue.title)
          expect(page).not_to have_link(weighted_issue_2.title)
        end
      end

      context 'when issue weights feature is not available' do
        before do
          stub_licensed_features(epics: true, quality_management: true, subepics: true, issue_weights: false)
          visit group_work_items_path(group)
        end

        it 'does not show weight filter token' do
          click_filtered_search_bar

          expect(page).not_to have_css('[data-testid="filtered-search-token-segment"]', text: 'Weight')
        end
      end
    end
  end
end
