# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Promotions', :js do
  # Ensure support bot user is created so creation doesn't count towards query limit
  # See https://gitlab.com/gitlab-org/gitlab/-/issues/509629
  let_it_be(:support_bot) { Users::Internal.support_bot }

  let(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }
  let(:otherdeveloper) { create(:user, name: 'TheOtherDeveloper') }
  let(:group) { create(:group) }
  let(:project) { create(:project, :repository, namespace: group) }
  let(:milestone) { create(:milestone, project: project, start_date: Date.today, due_date: 7.days.from_now) }
  let!(:issue) { create(:issue, project: project, author: user) }
  let(:otherproject) { create(:project, :repository, namespace: otherdeveloper.namespace) }

  before do
    stub_feature_flags(work_item_view_for_issues: true)
  end

  describe 'for merge request improve', :js, feature_category: :code_review_workflow do
    before do
      allow(License).to receive(:current).and_return(nil)
      stub_saas_features(gitlab_com_subscriptions: false)

      project.add_maintainer(user)
      sign_in(user)
    end

    it 'appears in project edit page' do
      visit project_settings_merge_requests_path(project)

      expect(find('#promote_mr_features')).to have_content 'Improve merge requests'
    end

    it 'does not show when cookie is set' do
      visit project_settings_merge_requests_path(project)

      within('#promote_mr_features') do
        find('.js-close').click
      end

      wait_for_requests

      visit project_settings_merge_requests_path(project)

      expect(page).not_to have_selector('#promote_mr_features')
    end
  end

  describe 'for repository features', :js, feature_category: :source_code_management do
    before do
      allow(License).to receive(:current).and_return(nil)
      stub_saas_features(gitlab_com_subscriptions: false)

      project.add_maintainer(user)
      sign_in(user)
    end

    it 'appears in repository settings page' do
      visit project_settings_repository_path(project)

      expect(find('#promote_repository_features')).to have_content(s_('Promotions|Improve repositories with GitLab Enterprise Edition.'))
    end

    it 'does not show when cookie is set' do
      visit project_settings_repository_path(project)

      within('#promote_repository_features') do
        find('.js-close').click
      end

      visit project_settings_repository_path(project)

      expect(page).not_to have_selector('#promote_repository_features')
    end
  end

  describe 'for burndown charts', :js, :saas, feature_category: :team_planning do
    let_it_be(:group) { create(:group_with_plan) }

    before do
      stub_saas_features(gitlab_com_subscriptions: true)
      stub_application_setting(check_namespace_plan: true)

      project.add_maintainer(user)
      sign_in(user)
    end

    it 'appears in milestone page' do
      visit project_milestone_path(project, milestone)

      expect(find('#promote_burndown_charts')).to have_content 'Upgrade your plan to improve milestones with Burndown Charts.'
    end

    it 'does not show when cookie is set' do
      visit project_milestone_path(project, milestone)

      within('#promote_burndown_charts') do
        find('.js-close').click
      end

      visit project_milestone_path(project, milestone)

      expect(page).not_to have_selector('#promote_burndown_charts')
    end
  end

  describe 'for epics in issues sidebar', :js, feature_category: :source_code_management do
    context 'when gitlab_com_subscriptions saas feature is available', :saas do
      let_it_be(:group) { create(:group_with_plan) }

      before do
        stub_saas_features(gitlab_com_subscriptions: true)

        project.add_maintainer(user)
        sign_in(user)
      end

      it 'shows promotion information in sidebar' do
        visit project_issue_path(project, issue)

        expect(page).to have_text 'Unlock epics, advanced boards, status, weight, iterations, and more to seamlessly tie your strategy to your DevSecOps workflows with GitLab.'
        expect(page).to have_link 'Try it for free'
      end
    end

    context 'when self hosted' do
      before do
        allow(License).to receive(:current).and_return(nil)
        stub_saas_features(gitlab_com_subscriptions: false)

        project.add_maintainer(user)
        sign_in(user)
      end

      it 'shows promotion information in sidebar' do
        visit project_issue_path(project, issue)

        expect(page).to have_text 'Unlock epics, advanced boards, status, weight, iterations, and more to seamlessly tie your strategy to your DevSecOps workflows with GitLab.'
        expect(page).to have_link 'Try it for free'
      end
    end
  end

  describe 'for issue weight', :js, feature_category: :team_planning do
    before do
      allow(License).to receive(:current).and_return(nil)
      stub_saas_features(gitlab_com_subscriptions: false)

      project.add_maintainer(user)
      sign_in(user)
    end

    it 'shows promotion information in sidebar' do
      visit project_issue_path(project, issue)

      expect(page).to have_text 'Unlock epics, advanced boards, status, weight, iterations, and more to seamlessly tie your strategy to your DevSecOps workflows with GitLab.'
      expect(page).to have_link 'Try it for free'
    end

    context 'when gitlab_com_subscriptions is available', :saas do
      let_it_be(:group) { create(:group_with_plan, owners: user) }

      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it 'shows promotion information in sidebar' do
        visit project_issue_path(project, issue)

        expect(page).to have_text 'Unlock epics, advanced boards, status, weight, iterations, and more to seamlessly tie your strategy to your DevSecOps workflows with GitLab.'
        expect(page).to have_link 'Try it for free'
      end
    end
  end

  describe 'for project audit events', :js, feature_category: :audit_events do
    before do
      allow(License).to receive(:current).and_return(nil)
      stub_saas_features(gitlab_com_subscriptions: false)

      project.add_maintainer(user)
      sign_in(user)
    end

    include_context '"Security and compliance" permissions' do
      let(:response) { inspect_requests { visit project_audit_events_path(project) }.first }
    end

    it 'appears on the page' do
      visit project_audit_events_path(project)

      expect(find('.gl-empty-state-content')).to have_content 'Keep track of events in your project'
    end
  end

  describe 'for group webhooks' do
    before do
      allow(License).to receive(:current).and_return(nil)
      stub_saas_features(gitlab_com_subscriptions: false)

      group.add_owner(user)
      sign_in(user)
    end

    it 'appears on the page' do
      visit group_hooks_path(group)

      expect(find('.gl-empty-state-content')).to have_content 'Add Group Webhooks'
    end
  end

  describe 'for advanced search', :js, feature_category: :global_search do
    before do
      allow(License).to receive(:current).and_return(nil)
      stub_saas_features(gitlab_com_subscriptions: false)

      sign_in(user)
    end

    it 'appears on seearch page' do
      visit search_path

      submit_search('chosen')

      expect(find('#promote_advanced_search')).to have_content 'Improve search with Advanced Search and GitLab Enterprise Edition.'
    end

    it 'does not show when cookie is set' do
      visit search_path
      submit_search('chosen')

      within('#promote_advanced_search') do
        find('.js-close').click
      end

      visit search_path
      submit_search('chosen')

      expect(page).not_to have_selector('#promote_advanced_search')
    end
  end

  def click_epic_link
    find('.js-epics-sidebar-callout .btn-link').click
  end
end
