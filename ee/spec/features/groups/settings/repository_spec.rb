# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'EE Group Repository settings', :js, feature_category: :source_code_management do
  include WaitForRequests

  let_it_be(:user) { create(:user) }
  let_it_be(:group, reload: true) { create(:group, owners: user) }

  before do
    sign_in(user)
  end

  context 'in General subsection' do
    context 'when feature `web_based_commit_signing_ui` is enabled' do
      before do
        group.namespace_settings.update!(web_based_commit_signing_enabled: true)
        stub_feature_flags(web_based_commit_signing_ui: true)
        visit group_settings_repository_path(group)
        wait_for_requests
      end

      it 'shows the setting section' do
        expect(page).to have_selector('#js-general-settings')
      end

      it 'shows web-based commit signing section' do
        expect(page).to have_css('[data-testid="web-based-commit-signing-checkbox"]')
        expect(page).to have_checked_field('Sign web-based commits')
      end
    end

    context 'when feature `web_based_commit_signing_ui` is not enabled' do
      before do
        stub_feature_flags(web_based_commit_signing_ui: false)
        visit group_settings_repository_path(group)
      end

      it 'does not show the setting section' do
        expect(page).not_to have_selector('#js-general-settings')
      end
    end
  end

  context 'in Protected branches subsection' do
    context 'when feature `group_protected_branches` is enabled' do
      before do
        stub_licensed_features(group_protected_branches: true)
        visit group_settings_repository_path(group)
      end

      it 'shows the setting section' do
        expect(page).to have_selector('#js-protected-branches-settings')
      end

      it 'does not show users in the access levels dropdown' do
        within('#js-protected-branches-settings') do
          click_button 'Add protected branch'
          find('.gl-dropdown-toggle.js-allowed-to-merge:not([disabled])').click
          wait_for_all_requests

          expect(page.find('.gl-dropdown-contents')).not_to have_content('Users')
        end
      end
    end

    context 'when feature `group_protected_branches` is not enabled' do
      before do
        visit group_settings_repository_path(group)
      end

      it 'does not show the setting section' do
        expect(page).not_to have_selector('#js-protected-branches-settings')
      end
    end
  end
end
