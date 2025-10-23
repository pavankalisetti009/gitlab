# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GitlabSubscriptionOneTimeCredits'], feature_category: :consumables_cost_management do
  it { expect(described_class.graphql_name).to eq('GitlabSubscriptionOneTimeCredits') }
  it { expect(described_class).to require_graphql_authorizations(:read_subscription_usage) }

  it 'has expected fields' do
    expect(described_class).to have_graphql_fields([:credits_used, :total_credits, :total_credits_remaining])
  end
end
