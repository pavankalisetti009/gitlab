# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Learn Gitlab concerns', :feature, :js, :saas, feature_category: :onboarding do
  include Features::InviteMembersModalHelpers
  include SubscriptionPortalHelpers

  context 'with learn gitlab links' do
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) { create(:group, owners: user) }
    let_it_be(:project) { create(:project, namespace: namespace) }

    before do
      # TODO: When removing the feature flag,
      # we won't need the tests for the issues listing page, since we'll be using
      # the work items listing page.
      stub_feature_flags(work_item_planning_view: false)
    end

    before_all do
      create(:onboarding_progress, namespace: namespace)
    end

    it 'renders correct links and navigates to project issues' do
      sign_in(user)
      visit namespace_project_learn_gitlab_path(namespace, project)

      issue_link = find_link('Create an issue')

      expect_correct_candidate_link(find_link('Create a repository'), project_path(project))

      expect_correct_candidate_link(issue_link, project_issues_path(project))
      expect_correct_candidate_link(find_link('Invite your colleagues'), '#')
      expect_correct_candidate_link(find_link("Set up your first project's CI/CD"), project_pipelines_path(project))
      expect_correct_candidate_link(find_link('Submit a merge request (MR)'), project_merge_requests_path(project))

      expect_correct_candidate_link(
        find_link('Analyze your application for vulnerabilities with DAST'),
        project_security_configuration_path(project, anchor: 'dast')
      )

      expect_correct_candidate_link(
        find_link('Start a free trial of GitLab Ultimate'),
        new_trial_path(glm_content: 'onboarding-start-trial')
      )

      expect_correct_candidate_link(
        find_link('Enable require merge approvals'),
        new_trial_path(glm_content: 'onboarding-require-merge-approvals')
      )

      expect_correct_candidate_link(
        find_link('Add code owners'),
        new_trial_path(glm_content: 'onboarding-code-owners')
      )

      issue_link.click
      expect(page).to have_current_path(project_issues_path(project))
    end

    context 'with invite members link opening invite modal' do
      before do
        sign_in(user)
        visit namespace_project_learn_gitlab_path(namespace, project)
      end

      it 'invites a user and completes the invite action and updates the completion status' do
        user_name_to_invite = create(:user).name

        within_testid('learn-gitlab-page') do
          find_link('Invite your colleagues').click
        end

        stub_signing_key
        stub_reconciliation_request(true)
        stub_subscription_request_seat_usage(false)

        invite_with_opened_modal(user_name_to_invite)

        expect(page).to have_content('Your team is growing')
      end
    end

    context 'when broadcast messages exists' do
      let_it_be(:group) do
        create(
          :group_with_plan, :private,
          plan: :ultimate_trial_plan,
          trial: true,
          trial_starts_on: Date.today,
          trial_ends_on: 10.days.from_now,
          owners: user
        ) do |g|
          create(:onboarding_progress, namespace: g)
        end
      end

      let_it_be(:project) { create(:project, namespace: group) }
      let_it_be(:broadcast_message_1) { create(:broadcast_message, message: 'broadcast message example 1') }
      let_it_be(:broadcast_message_2) { create(:broadcast_message, message: 'broadcast message example 2') }

      before do
        sign_in(user)

        visit namespace_project_learn_gitlab_path(group, project)
      end

      it 'does not show any broadcast message' do
        expect(page).not_to have_content('broadcast message example 1')
        expect(page).not_to have_content('broadcast message example 2')
      end
    end

    context 'when the duo chat popover exists' do
      let_it_be(:group) do
        create(
          :group_with_plan, :private,
          plan: :ultimate_trial_plan,
          trial: true,
          trial_starts_on: Date.today,
          trial_ends_on: 10.days.from_now,
          owners: user
        ) do |g|
          create(:onboarding_progress, namespace: g)
        end
      end

      let_it_be(:project) { create(:project, namespace: group) }

      include_context 'with duo features enabled and ai chat available for group on SaaS'

      context 'when the cookie `confetti_post_signup` is true' do
        before do
          sign_in(user)

          set_cookie('confetti_post_signup', 'true')

          visit namespace_project_learn_gitlab_path(group, project)
        end

        it 'does not show the duo chat promo popover initially' do
          expect(page).not_to have_selector('[data-testid="duo-chat-promo-callout-popover"]')
        end

        it 'shows the duo chat promo popover after a page refresh' do
          page.refresh

          find_by_testid('ai-chat-toggle').click if Users::ProjectStudio.enabled_for_user?(user) # rubocop:disable RSpec/AvoidConditionalStatements -- temporary Project Studio rollout
          expect(page).to have_selector('[data-testid="duo-chat-promo-callout-popover"]')
        end
      end

      context 'when the cookie `confetti_post_signup` is false' do
        before do
          sign_in(user)

          set_cookie('confetti_post_signup', 'false')

          visit namespace_project_learn_gitlab_path(group, project)
        end

        it 'shows the duo chat promo popover' do
          find_by_testid('ai-chat-toggle').click if Users::ProjectStudio.enabled_for_user?(user) # rubocop:disable RSpec/AvoidConditionalStatements -- temporary Project Studio rollout

          expect(page).to have_selector('[data-testid="duo-chat-promo-callout-popover"]')
        end
      end
    end

    context 'with an active trial' do
      let_it_be(:group) do
        create(
          :group_with_plan, :private,
          plan: :ultimate_trial_plan,
          trial: true,
          trial_starts_on: Date.today,
          trial_ends_on: 10.days.from_now,
          owners: user
        ) do |g|
          create(:onboarding_progress, namespace: g)
        end
      end

      let_it_be(:project) { create(:project, namespace: group) }

      before do
        stub_ee_application_setting(dashboard_limit_enabled: true)

        sign_in(user)
      end

      context 'when onboarding progress is less than one day' do
        it 'does not render the unlimited members during trial alert' do
          visit namespace_project_learn_gitlab_path(group, project)

          expect(page).not_to have_text('Get the most out of your trial with space for more members')
        end
      end

      context 'when onboarding progress is more than one day' do
        before do
          group.onboarding_progress.update!(created_at: 1.day.ago)
        end

        it 'does render the unlimited members during trial alert' do
          visit namespace_project_learn_gitlab_path(group, project)

          expect(page).to have_text('Get the most out of your trial with space for more members')
          expect(page).to have_link(text: 'Explore paid plans', href: group_billings_path(group))
          expect(page).to have_button('Invite more members')

          click_button 'Invite more members'

          expect(page).to have_selector(invite_modal_selector)
        end
      end
    end

    def expect_correct_candidate_link(link, path)
      expect(link['href']).to include(path)
      expect(link['data-testid']).to eq('learn-gitlab-link')
    end
  end
end
