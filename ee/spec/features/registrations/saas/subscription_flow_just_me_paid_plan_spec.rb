# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Subscription flow for user picking just me for paid plan', :js, :saas_registration, :with_default_organization, feature_category: :onboarding do
  where(:case_name, :sign_up_method) do
    [
      ['with regular sign up', -> { subscription_regular_sign_up }],
      ['with sso sign up', -> { sso_subscription_sign_up }]
    ]
  end

  with_them do
    it 'registers the user, processes subscription purchase and creates a group' do
      allow_next_instance_of(GitlabSubscriptions::PurchaseUrlBuilder) do |instance|
        allow(instance).to receive(:customers_dot_flow?).and_return(false)
      end

      has_billing_account = false
      stub_get_billing_account(has_billing_account: has_billing_account)
      sign_up_method.call

      expect_to_see_subscription_welcome_form
      expect_not_to_send_iterable_request

      fills_in_welcome_form
      click_on 'Continue'

      expect_to_see_checkout_form

      fill_in_checkout_form(has_billing_account: has_billing_account)

      expect_to_see_subscriptions_group_edit_page

      fill_in 'Group name (your organization)', with: '@invalid group name'

      click_on 'Get started'

      expect_to_see_group_validation_errors

      fill_in 'Group name (your organization)', with: 'Test group'

      click_on 'Get started'

      expect_to_see_group_overview_page
    end
  end

  def fills_in_welcome_form
    stub_subscription_customers_dot_requests

    select 'Software Developer', from: 'user_role'
    select 'A different reason', from: 'user_registration_objective'
    fill_in 'Why are you signing up? (optional)', with: 'My reason'

    choose 'Just me'
    check _("I'd like to receive updates about GitLab via email")
    choose 'Create a new project' # does not matter here if choose 'Join a project'
  end
end
