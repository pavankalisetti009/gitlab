# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Issues', :js, feature_category: :team_planning do
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:auditor) { create(:user, auditor: true) }

  before do
    # TODO: When removing the feature flag,
    # we won't need the tests for the issues listing page, since we'll be using
    # the work items listing page.
    stub_feature_flags(work_item_planning_view: false)
    stub_feature_flags(work_item_view_for_issues: true)
  end

  shared_examples 'empty state' do |expect_button|
    it "shows empty state #{expect_button ? 'with' : 'without'} \"Create issue\" button" do
      visit project_issues_path(project)

      expect(page).to have_content('Track bugs, plan features, and organize your work with issues')
      expect(page.has_link?('New item', exact: true)).to be(expect_button)
    end
  end

  context 'when signed in user is an Auditor' do
    before do
      sign_in(auditor)
    end

    context 'when user is not a member of the project' do
      it_behaves_like 'empty state', false
    end

    context 'when user is a member of the project' do
      before do
        project.add_guest(auditor)
      end

      it_behaves_like 'empty state', true
    end
  end
end
