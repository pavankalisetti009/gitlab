# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::SubscriptionPortal::Client, feature_category: :consumables_cost_management do
  subject { described_class }

  it { is_expected.to include_module Gitlab::SubscriptionPortal::Clients::Graphql }
  it { is_expected.to include_module Gitlab::SubscriptionPortal::Clients::Rest }
end
