# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab_subscriptions routing', feature_category: :subscription_management do
  it 'routes to track_cart_abandonment' do
    expect(post('/-/gitlab_subscriptions/hand_raise_leads/track_cart_abandonment')).to route_to(
      controller: 'gitlab_subscriptions/hand_raise_leads',
      action: 'track_cart_abandonment'
    )
  end

  it "routes to TrialsController when constraint matches saas", :saas_subscriptions_trials do
    expect(get('/-/trials/new')).to route_to('gitlab_subscriptions/trials#new')
  end

  it "routes to SelfManaged::TrialsController when constraint does not match saas" do
    expect(get('/-/trials/new')).to route_to('gitlab_subscriptions/self_managed/trials#new')
  end
end
