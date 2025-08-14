# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin Projects', feature_category: :permissions do
  context 'when current user is an admin', :js do
    let_it_be(:current_user) { create(:admin) }

    before do
      enable_admin_mode!(current_user)
      sign_in(current_user)
    end

    describe 'list' do
      let_it_be(:project) { create(:project) }

      it 'renders admin-only buttons' do
        visit admin_projects_path

        expect(page).to have_content("New Project")
      end

      it 'renders admin-only action buttons' do
        visit admin_projects_path

        expect(page).to have_content(project.name)

        find_by_testid('groups-projects-more-actions-dropdown').click

        within_testid('groups-projects-more-actions-dropdown') do
          expect(page).to have_content('Edit')
          expect(page).to have_content('Delete')
        end
      end
    end
  end
end
