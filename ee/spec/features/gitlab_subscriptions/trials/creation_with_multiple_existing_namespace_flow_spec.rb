# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Trial lead submission and creation with multiple eligible namespaces', :saas_trial, :js, :use_clean_rails_memory_store_caching, feature_category: :acquisition do
  let_it_be(:user) { create(:user) } # rubocop:disable Gitlab/RSpec/AvoidSetup -- to skip registration and creating group
  let_it_be(:group) do # rubocop:disable Gitlab/RSpec/AvoidSetup -- to skip registration and creating group
    create(:group, owners: user)
    create(:group, name: 'gitlab', owners: user)
  end

  before_all do
    create(:gitlab_subscription_add_on, :duo_enterprise)
  end

  context 'when creating lead and applying trial is successful' do
    it 'fills out form, submits and lands on the duo page' do
      sign_in(user)

      stub_cdot_namespace_eligible_trials
      visit new_trial_path

      fill_in_company_information
      fill_in_trial_selection_form

      submit_trial_form

      expect_to_be_on_gitlab_duo_page
    end

    context 'when new trial is selected from within an existing namespace' do
      it 'fills out form, has the existing namespace preselected, submits and lands on the duo page' do
        glm_params = { glm_source: '_glm_source_', glm_content: '_glm_content_' }

        sign_in(user)

        stub_cdot_namespace_eligible_trials
        visit new_trial_path(namespace_id: group.id, **glm_params)

        fill_in_company_information
        fill_in_trial_selection_form(from: group.name)

        submit_trial_form(glm: glm_params)

        expect_to_be_on_gitlab_duo_page
      end
    end

    context 'when part of the discover security flow' do
      it 'fills out form, submits and lands on the group security dashboard page' do
        sign_in(user)

        stub_cdot_namespace_eligible_trials
        visit new_trial_path(glm_content: 'discover-group-security')

        fill_in_company_information
        fill_in_trial_selection_form

        submit_trial_form(glm: { glm_content: 'discover-group-security' })

        expect_to_be_on_group_security_dashboard
      end
    end
  end

  context 'when applying lead fails' do
    it 'fills out form, submits and sent back to information form with errors and is then resolved' do
      # setup
      sign_in(user)

      stub_cdot_namespace_eligible_trials
      visit new_trial_path

      fill_in_company_information
      fill_in_trial_selection_form

      # lead failure
      submit_trial_form(lead_result: lead_failure)

      expect_to_be_on_form_with_trial_submission_error

      # success
      resubmit_full_request

      expect_to_be_on_gitlab_duo_page
    end
  end

  context 'when applying trial fails' do
    it 'fills out form, submits and is sent to select namespace with errors and is then resolved' do
      # setup
      sign_in(user)

      stub_cdot_namespace_eligible_trials
      visit new_trial_path

      fill_in_company_information
      fill_in_trial_selection_form

      # trial failure
      submit_trial_form(trial_result: trial_failure)

      expect_to_be_on_form_with_trial_submission_error

      # success
      resubmit_trial_request

      expect_to_be_on_gitlab_duo_page
    end
  end

  def submit_trial_form(
    lead_result: ServiceResponse.success,
    trial_result: ServiceResponse.success,
    extra_params: {},
    glm: {}
  )
    # lead
    expect_lead_submission(lead_result, glm: glm)

    # trial
    if lead_result.success? # rubocop:disable RSpec/AvoidConditionalStatements -- Not a concern for the cop's reasons
      stub_apply_trial(
        namespace_id: group.id,
        result: trial_result,
        extra_params: extra_params.merge(existing_group_attrs).merge(glm)
      )
      stub_duo_landing_page_data
    end

    click_button 'Activate my trial'

    wait_for_requests
  end
end
