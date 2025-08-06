# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin Projects', feature_category: :permissions do
  let_it_be_with_reload(:project) { create(:project) }

  context 'when user is a regular user with read_admin_projects custom admin role', :js do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:role) { create(:admin_member_role, :read_admin_projects, user: current_user) }

    before do
      stub_licensed_features(custom_roles: true)

      enable_admin_mode!(current_user)

      sign_in(current_user)
    end

    describe 'list' do
      it 'renders without admin-only buttons',
        pending: "Not supported in new Vue dashboard: https://gitlab.com/gitlab-org/gitlab/-/issues/557844" do
        visit admin_projects_path

        expect(page).to have_content(project.name)
        expect(page).not_to have_content("New Project")
        expect(page).not_to have_content("Edit")
        expect(page).not_to have_content("Delete")
      end
    end

    describe 'show', :aggregate_failures do
      it 'shows the project without admin-only buttons' do
        visit admin_project_path(project)

        expect(page).to have_content project.name
        expect(page).not_to have_content("Edit")
      end
    end
  end
end
