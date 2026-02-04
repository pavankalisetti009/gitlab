# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Promotions', :js, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }

  let(:admin) { create(:admin) }
  let(:otherdeveloper) { create(:user, name: 'TheOtherDeveloper') }
  let(:group) { create(:group) }
  let(:project) { create(:project, :repository, namespace: group) }
  let(:milestone) { create(:milestone, project: project, start_date: Date.today, due_date: 7.days.from_now) }
  let!(:issue) { create(:issue, project: project, author: user) }
  let(:otherproject) { create(:project, :repository, namespace: otherdeveloper.namespace) }

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

  def click_epic_link
    find('.js-epics-sidebar-callout .btn-link').click
  end
end
