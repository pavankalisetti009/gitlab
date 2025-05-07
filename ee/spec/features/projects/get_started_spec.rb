# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Get started concerns', :js, :saas, :aggregate_failures, feature_category: :onboarding do
  include Features::InviteMembersModalHelpers

  context 'for Getting started page' do
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) { create(:group, owners: user) }
    let_it_be(:project) { create(:project, namespace: namespace) }

    context 'for overall rendering' do
      before_all do
        create(:onboarding_progress, namespace: namespace)
      end

      it 'renders sections correctly' do
        sign_in(user)

        visit namespace_project_get_started_path(namespace, project)

        within_testid('get-started-sections') do
          expect(page).to have_content('Quick start')
          expect(page).to have_content('Follow these steps to get familiar with the GitLab workflow.')
          expect(page).to have_content('Set up your code')
          expect(page).to have_content('Configure a project')
          expect(page).to have_content('Plan and execute work together')
          expect(page).to have_content('Secure your deployment')
        end
      end

      it 'renders modal link and opens modal correctly' do
        sign_in(user)

        visit namespace_project_get_started_path(namespace, project)

        find_by_testid('section-header-1').click
        find_link('Invite your colleagues').click

        page.within invite_modal_selector do
          expect(page).to have_content("You're inviting members to the #{project.name} project")
        end
      end
    end

    context 'with completed links' do
      before do
        create(:onboarding_progress, namespace: namespace, code_added_at: Date.yesterday)
      end

      it 'renders correct completed sections' do
        sign_in(user)

        visit namespace_project_get_started_path(namespace, project)

        within_testid('get-started-sections') do
          expect_completed_section('Create a repository')
          expect_completed_section('Add code to a repository')
        end
      end
    end

    def expect_completed_section(text)
      expect(page).to have_no_link(text)
      expect(page).to have_content(text)
    end
  end
end
