# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Discovers > Hand Raise Lead', :js, :saas, feature_category: :activation do
  include Features::HandRaiseLeadHelpers
  include SubscriptionPortalHelpers

  let_it_be(:user) { create(:user, :with_namespace, user_detail_organization: 'YMCA') }
  let_it_be(:group) do
    create(
      :group_with_plan, plan: :ultimate_trial_plan,
      trial_starts_on: Date.today, trial_ends_on: Date.tomorrow, owners: user
    )
  end

  before do
    stub_saas_features(subscriptions_trials: true)
    stub_billing_plans(group.id, 'ultimate_trial')

    sign_in(user)

    visit group_discover_path(group)
  end

  context 'when user interacts with hand raise lead and submits' do
    it 'renders and submits the hand raise lead button' do
      all_by_testid('expert-contact-hand-raise-lead-button').first.click

      fill_in_and_submit_hand_raise_lead(user, group, glm_content: 'billing-group')
    end
  end
end
