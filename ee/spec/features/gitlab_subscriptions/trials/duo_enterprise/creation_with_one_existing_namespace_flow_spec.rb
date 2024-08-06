# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Enterprise trial lead submission and creation with one eligible namespace', :saas_trial, :js, feature_category: :acquisition do
  include SubscriptionPortalHelpers

  # rubocop:disable Gitlab/RSpec/AvoidSetup -- to skip registration and creating group
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan, name: 'gitlab', owners: user) }

  before_all do
    create(:gitlab_subscription_add_on_purchase, :duo_enterprise)
  end

  before do
    stub_licensed_features(code_suggestions: true)
    stub_signing_key
    stub_subscription_permissions_data(group.id)
  end
  # rubocop:enable Gitlab/RSpec/AvoidSetup

  context 'when creating lead and applying trial is successful' do
    it 'fills out form, submits and lands on the group usage quotas page' do
      sign_in(user)

      visit new_trials_duo_enterprise_path

      fill_in_company_information

      submit_duo_enterprise_trial_company_form(with_trial: true)

      expect_to_be_on_gitlab_duo_usage_quotas_page
    end
  end

  context 'when applying lead fails' do
    it 'fills out form, submits and sent back to information form with errors and is then resolved' do
      # setup
      sign_in(user)

      visit new_trials_duo_enterprise_path

      fill_in_company_information

      # lead failure
      submit_duo_enterprise_trial_company_form(lead_success: false)

      expect_to_be_on_lead_form_with_errors

      # success
      submit_duo_enterprise_trial_company_form(with_trial: true)

      expect_to_be_on_gitlab_duo_usage_quotas_page
    end
  end

  context 'when applying trial fails' do
    it 'fills out form, submits and is sent back to information form with errors  and is then resolved' do
      # setup
      sign_in(user)

      visit new_trials_duo_enterprise_path

      fill_in_company_information

      # trial failure
      submit_duo_enterprise_trial_company_form(with_trial: true, trial_success: false)

      aggregate_failures 'content and link' do
        expect(page).to have_content('could not be created because our system did not respond successfully')
        expect(page).to have_content('Please try again or reach out to GitLab Support.')
        expect(page).to have_link('GitLab Support', href: 'https://support.gitlab.com/hc/en-us')
      end

      wait_for_all_requests

      # success
      submit_duo_enterprise_trial_company_form(with_trial: true)

      expect_to_be_on_gitlab_duo_usage_quotas_page
    end
  end
end
