# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'profiles/billings/index.html.haml', :saas, feature_category: :subscription_management do
  include StubRequests
  include SubscriptionPortalHelpers

  let(:namespace) { build_stubbed(:namespace) }
  let(:user) { build_stubbed(:user, namespace: namespace) }
  let(:free_group) { build_stubbed(:group) }
  let(:trial_group) { build_stubbed(:group) }

  let(:premium_plan) { Hashie::Mash.new(code: ::Plan::PREMIUM, id: 1, name: 'Premium') }
  let(:ultimate_plan) { Hashie::Mash.new(code: ::Plan::ULTIMATE, id: 2, name: 'Ultimate') }
  let(:plans_data) { [premium_plan, ultimate_plan] }

  before do
    stub_signing_key
    stub_application_setting(check_namespace_plan: true)
    stub_saas_features(experimentation: true)

    assign(:plans_data, plans_data)

    allow(user).to receive_messages(
      free_or_trial_owned_group_ids: [1, 2]
    )

    allow(user).to receive_message_chain(:owned_groups, :free_or_trial, :empty?).and_return(false)

    allow(namespace).to receive_messages(
      actual_plan_name: 'free',
      paid?: false
    )

    allow(view).to receive_messages(
      current_user: user,
      subscription_plan_info: premium_plan,
      subscription_plan_data_attributes: {
        namespace_id: namespace.id,
        namespace_name: namespace.name,
        plan_name: premium_plan.code
      },
      user_billing_data_attributes: {
        groups: [
          { id: 1, name: 'Free Group', trial_active: false },
          { id: 2, name: 'Trial Group', trial_active: true }
        ]
      }
    )
  end

  context 'with user_billing_pricing_information experiment', :experiment do
    it 'renders control variant' do
      stub_experiments(user_billing_pricing_information: :control)

      render

      expect(rendered).to have_css('#js-billing-plans')
    end

    it 'renders candidate variant' do
      stub_experiments(user_billing_pricing_information: :candidate)

      render

      expect(rendered).to have_css('#js-pricing-information')
    end
  end
end
