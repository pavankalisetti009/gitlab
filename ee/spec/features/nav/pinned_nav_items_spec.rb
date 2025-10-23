# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Navigation menu item pinning', :js, feature_category: :navigation do
  describe 'default pins in nav items experiment', :experiment, :saas do
    let_it_be(:user) do
      build(:user, :with_namespace, id: non_existing_record_id) do |u|
        u.user_detail.update!(onboarding_status: {
          registration_type: 'trial',
          role: 0, # software_developer
          registration_objective: 1, # move_repository
          experiments: ['default_pinned_nav_items']
        })
      end
    end

    let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan, owners: user) }
    let_it_be(:project) { create(:project, :repository, group: group) }

    before do
      stub_licensed_features(epics: true)

      sign_in(user)
    end

    it 'shows group candidate pins' do
      stub_experiments(default_pinned_nav_items: :candidate)
      visit group_path(group)

      within_testid 'pinned-nav-items' do
        nav_ids = %i[members group_issue_list group_merge_request_list]
        nav_ids.each { |nav_id| expect(page).to have_css("a[data-track-label='#{nav_id}']") }
      end
    end

    it 'shows group control pins' do
      stub_experiments(default_pinned_nav_items: :control)
      visit group_path(group)

      within_testid 'pinned-nav-items' do
        nav_ids = %i[group_issue_list group_merge_request_list]
        nav_ids.each { |nav_id| expect(page).to have_css("a[data-track-label='#{nav_id}']") }
      end
    end

    it 'shows project candidate pins' do
      stub_experiments(default_pinned_nav_items: :candidate)
      visit project_path(project)

      within_testid 'pinned-nav-items' do
        nav_ids = %i[files pipelines members project_merge_request_list project_issue_list]
        nav_ids.each { |nav_id| expect(page).to have_css("a[data-track-label='#{nav_id}']") }
      end
    end

    it 'shows project control pins' do
      stub_experiments(default_pinned_nav_items: :control)
      visit project_path(project)

      within_testid 'pinned-nav-items' do
        nav_ids = %i[project_issue_list project_merge_request_list]
        nav_ids.each { |nav_id| expect(page).to have_css("a[data-track-label='#{nav_id}']") }
      end
    end
  end
end
