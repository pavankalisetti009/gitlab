# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Start trial from external site without confirmation', :with_current_organization,
  :saas, :js, :sidekiq_inline, feature_category: :onboarding do
  include SaasRegistrationHelpers

  let_it_be(:glm_params) do
    { glm_source: 'some_source', glm_content: 'some_content' }
  end

  let_it_be(:trials_eligibility_url) do
    %r{#{subscription_portal_url}/api/v1/gitlab/namespaces/trials/eligibility\?namespace_ids.*}
  end

  let_it_be(:trial_types_response) do
    {
      trial_types: {
        GitlabSubscriptions::Trials::FREE_TRIAL_TYPE => { duration_days: 30 }
      }
    }
  end

  before do
    stub_application_setting(require_admin_approval_after_user_signup: false)
    stub_application_setting(import_sources: %w[github gitlab_project])

    # The groups_and_projects_controller (on `click_on 'Create project'`) is over
    # the query limit threshold, so we have to adjust it.
    # https://gitlab.com/gitlab-org/gitlab/-/issues/340302
    allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(163)

    subscription_portal_url = ::Gitlab::Routing.url_helpers.subscription_portal_url

    stub_feature_flags(new_trial_lead_endpoint: false)

    stub_request(:post, "#{subscription_portal_url}/trials")
    stub_request(:get, trials_eligibility_url)

    stub_request(:get, "#{subscription_portal_url}/api/v1/gitlab/namespaces/trials/trial_types").to_return(
      status: 200,
      body: trial_types_response.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end

  it 'passes glm parameters until user is onboarded' do
    user = build_stubbed(:user)

    expect(Gitlab::SubscriptionPortal::Client)
      .to receive(:namespace_trial_types)
      .twice
      .and_call_original

    visit new_trial_registration_path(glm_params)

    fill_in_sign_up_form(user)

    select 'Software Developer', from: 'user_onboarding_status_role'
    choose 'My company or team'
    click_button 'Continue'

    expect(Gitlab::SubscriptionPortal::Client)
      .to receive(:generate_trial)
      .with(hash_including(glm_params))
      .and_call_original

    fill_in 'company_name', with: 'Company name'
    select_from_listbox 'Australia', from: 'Select a country or region'

    click_button 'Continue'

    fill_in 'group_name', with: 'Group name'
    fill_in 'blank_project_name', with: 'Project name'
    click_button 'Create project'

    expect_to_be_in_get_started
  end
end
