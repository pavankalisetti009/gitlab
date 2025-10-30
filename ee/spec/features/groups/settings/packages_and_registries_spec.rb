# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group > Settings > Packages and registries', :aggregate_failures,
  feature_category: :package_registry do
  include WaitForRequests

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: group) }

  describe 'Virtual registry' do
    before do
      stub_configuration
      sign_in(user)
    end

    context 'when user is not authorised' do
      it 'cleanup policy page renders 404' do
        visit_virtual_registry_cleanup_policy_page

        expect(page).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is authorised', :js do
      before_all do
        group.add_owner(user)
      end

      it 'sub-group settings page does not have section' do
        visit_sub_group_settings_page

        expect(page).not_to have_selector('h2', text: 'Virtual registry')
      end

      it 'group settings page has section and toggling off setting disallows access' do
        visit_settings_page
        wait_for_requests

        expect(page).to have_selector('h2', text: 'Virtual registry')

        within_testid 'virtual-registries-setting' do
          click_button class: 'gl-toggle'
        end

        expect(find('.gl-toast')).to have_content('Settings saved successfully.')

        visit group_virtual_registries_path(group)
        expect(page).to have_content 'Page not found'
      end

      it 'cleanup policy page has a page title set' do
        visit_virtual_registry_cleanup_policy_page

        expect(page).to have_selector('h1', text: 'Virtual registry cache cleanup policy')

        within_testid('super-sidebar') do
          expect(page).to have_selector('button[aria-expanded="true"]', text: 'Settings')
          expect(page).to have_selector('[aria-current="page"]', text: 'Packages and registries')
        end
      end
    end
  end

  private

  def stub_configuration
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
  end

  def visit_settings_page
    visit group_settings_packages_and_registries_path(group)
  end

  def visit_sub_group_settings_page
    visit group_settings_packages_and_registries_path(sub_group)
  end

  def visit_virtual_registry_cleanup_policy_page
    visit group_settings_packages_and_registries_virtual_registry_cleanup_policy_index_path(group)
  end
end
