# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GitlabSubscriptionUsage'], feature_category: :consumables_cost_management do
  it { expect(described_class.graphql_name).to eq('GitlabSubscriptionUsage') }
  it { expect(described_class).to require_graphql_authorizations(:read_subscription_usage) }

  it 'has expected fields' do
    expect(described_class).to have_graphql_fields([
      :last_event_transaction_at,
      :start_date,
      :end_date,
      :purchase_credits_path,
      :one_time_credits,
      :monthly_commitment,
      :overage,
      :users_usage
    ])
  end
end
