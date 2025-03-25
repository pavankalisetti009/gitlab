# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AmazonQ routing', feature_category: :ai_agents do
  describe AmazonQ::QuickActionsController, 'routing' do
    it 'routes POST /-/amazon_q/quick_actions to quick_actions#create' do
      expect(post('/-/amazon_q/quick_actions'))
        .to route_to('amazon_q/quick_actions#create')
    end
  end
end
