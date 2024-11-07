# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Subscriptions routing', feature_category: :subscription_management do
  describe '/-/subscriptions/hand_raise_leads' do
    subject { post('/-/subscriptions/hand_raise_leads') }

    it { is_expected.to route_to('gitlab_subscriptions/hand_raise_leads#create') }
  end
end
