# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GitlabSubscriptionUsageUsersUsage'], feature_category: :consumables_cost_management do
  it { expect(described_class.graphql_name).to eq('GitlabSubscriptionUsageUsersUsage') }
  it { expect(described_class).to require_graphql_authorizations(:read_subscription_usage) }

  it 'has expected fields' do
    expect(described_class).to have_graphql_fields([
      :total_users_using_credits,
      :total_users_using_pool,
      :total_users_using_overage,
      :daily_usage,
      :users
    ])
  end

  it 'sets max_page_size of 20 to users field' do
    expect(described_class.fields['users'].max_page_size).to eq(20)
  end
end
