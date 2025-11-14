# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab_subscriptions routing', feature_category: :subscription_management do
  it 'routes to track_cart_abandonment' do
    expect(post('/-/gitlab_subscriptions/hand_raise_leads/track_cart_abandonment')).to route_to(
      controller: 'gitlab_subscriptions/hand_raise_leads',
      action: 'track_cart_abandonment'
    )
  end
end
