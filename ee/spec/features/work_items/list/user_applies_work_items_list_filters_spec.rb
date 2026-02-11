# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers -- using filter would need multiple creation with different criteria
RSpec.describe 'Work items list filters', :js, feature_category: :team_planning do
  include FilteredSearchHelpers
  include WorkItemFeedbackHelpers

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

  let_it_be(:issue_on_track) { create(:issue, project: project, health_status: 'on_track') }
  let_it_be(:issue_needs_attention) { create(:issue, project: project, health_status: 'needs_attention') }
  let_it_be(:issue_at_risk) { create(:issue, project: project, health_status: 'at_risk') }
  let_it_be(:issue_no_health) { create(:issue, project: project, health_status: nil) }

  let_it_be(:iteration_cadence) { create(:iterations_cadence, group: group) }
  let_it_be(:iteration_1) { create(:iteration, iterations_cadence: iteration_cadence, title: 'Iteration 1') }
  let_it_be(:iteration_2) { create(:iteration, iterations_cadence: iteration_cadence, title: 'Iteration 2') }
  let_it_be(:issue_with_iteration_1) { create(:issue, project: project, iteration: iteration_1) }
  let_it_be(:issue_with_iteration_2) { create(:issue, project: project, iteration: iteration_2) }
  let_it_be(:issue_without_iteration) { create(:issue, project: project, iteration: nil) }

  def expect_work_items_list_count(count)
    expect(page).to have_css('.issue', count: count)
  end

  before_all do
    create(:callout, user: user, feature_name: :work_items_onboarding_modal)
  end

  context 'for signed in user' do
    before do
      stub_licensed_features(epics: true, quality_management: true, subepics: true, issue_weights: true,
        issuable_health_status: true, work_item_status: true, iterations: true)
      sign_in(user)
      visit group_work_items_path(group)
      close_work_item_feedback_popover_if_present
    end

    describe 'group' do
      it 'filters', :aggregate_failures,
        quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/9503' do
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

        expect(page).to have_css('.issue', count: 13)
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

    describe 'health' do
      before do
        visit project_work_items_path(project)
      end

      describe 'behavior' do
        it 'loads all health status options when opened' do
          select_tokens 'Health', '='

          # Expect None, Any, on_track, needs_attention, at_risk
          expect_suggestion_count 5
        end
      end

      describe 'only health' do
        it 'filters work items by on_track health status' do
          select_tokens 'Health', '=', 'On track', submit: true

          expect_work_items_list_count(1)
          expect(page).to have_link(issue_on_track.title)
        end

        it 'filters work items by needs_attention health status' do
          select_tokens 'Health', '=', 'Needs attention', submit: true

          expect_work_items_list_count(1)
          expect(page).to have_link(issue_needs_attention.title)
        end

        it 'filters work items by at_risk health status' do
          select_tokens 'Health', '=', 'At risk', submit: true

          expect_work_items_list_count(1)
          expect(page).to have_link(issue_at_risk.title)
        end
      end

      describe 'health wildcards' do
        it 'filters work items by None health status' do
          select_tokens 'Health', '=', 'None', submit: true

          expect(page).to have_link(issue_no_health.title)
          expect(page).not_to have_link(issue_on_track.title)
          expect(page).not_to have_link(issue_needs_attention.title)
          expect(page).not_to have_link(issue_at_risk.title)
        end

        it 'filters work items by Any health status' do
          select_tokens 'Health', '=', 'Any', submit: true

          expect_work_items_list_count(3)
          expect(page).to have_link(issue_on_track.title)
          expect(page).to have_link(issue_needs_attention.title)
          expect(page).to have_link(issue_at_risk.title)
          expect(page).not_to have_link(issue_no_health.title)
        end
      end

      describe 'negated health only' do
        it 'excludes work items with specified health status' do
          select_tokens 'Health', '!=', 'On track', submit: true

          expect(page).to have_link(issue_needs_attention.title)
          expect(page).to have_link(issue_at_risk.title)
          expect(page).to have_link(issue_no_health.title)
          expect(page).not_to have_link(issue_on_track.title)
        end
      end

      context 'when issuable health status feature is not available' do
        before do
          stub_licensed_features(epics: true, quality_management: true, subepics: true, issuable_health_status: false)
          visit group_work_items_path(group)
        end

        it 'does not show health filter token' do
          click_filtered_search_bar

          expect(page).not_to have_css('[data-testid="filtered-search-token-segment"]', text: 'Health')
        end
      end
    end

    describe 'status' do
      before do
        visit project_work_items_path(project)
      end

      describe 'behavior' do
        it 'loads all the statuses when opened' do
          select_tokens 'Status'

          # Expect default system defined statuses
          expect_suggestion_count 5
        end
      end

      describe 'only status' do
        it 'filters work items by in progress status' do
          select_tokens 'Status', 'In progress', submit: true

          expect_work_items_list_count(0)
        end

        it 'filters work items by to do status' do
          select_tokens 'Status', 'To do', submit: true

          expect_work_items_list_count(13)
        end
      end

      context 'when status feature is not available' do
        before do
          stub_licensed_features(epics: true, quality_management: true, subepics: true, issue_weights: false,
            work_item_status: false)
          visit group_work_items_path(group)
        end

        it 'does not show status filter token' do
          click_filtered_search_bar

          expect(page).not_to have_css('[data-testid="filtered-search-token-segment"]', text: 'Status')
        end
      end
    end

    describe 'iteration' do
      before do
        visit project_work_items_path(project)
      end

      describe 'only iteration' do
        it 'filters work items by specified iteration' do
          select_tokens 'Iteration', '=', 'Iteration 1', submit: true

          expect_work_items_list_count(1)
          expect(page).to have_link(issue_with_iteration_1.title)
        end
      end

      describe 'iteration wildcards' do
        it 'filters work items by None iteration' do
          select_tokens 'Iteration', '=', 'None', submit: true

          expect(page).to have_link(issue_without_iteration.title)
          expect(page).not_to have_link(issue_with_iteration_1.title)
          expect(page).not_to have_link(issue_with_iteration_2.title)
        end

        it 'filters work items by Any iteration' do
          select_tokens 'Iteration', '=', 'Any', submit: true

          expect_work_items_list_count(2)
          expect(page).to have_link(issue_with_iteration_1.title)
          expect(page).to have_link(issue_with_iteration_2.title)
          expect(page).not_to have_link(issue_without_iteration.title)
        end
      end

      describe 'negated iteration only' do
        it 'excludes work items with specified iteration' do
          select_tokens 'Iteration', '!=', 'Iteration 1', submit: true

          expect(page).to have_link(issue_with_iteration_2.title)
          expect(page).to have_link(issue_without_iteration.title)
          expect(page).not_to have_link(issue_with_iteration_1.title)
        end
      end

      context 'when iterations feature is not available' do
        before do
          stub_licensed_features(iterations: false)
          visit project_work_items_path(project)
        end

        it 'does not show iteration filter token' do
          click_filtered_search_bar

          expect(page).not_to have_css('[data-testid="filtered-search-token-segment"]', text: 'Iteration')
        end
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
