# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Container::UpstreamPolicy, feature_category: :virtual_registry do
  let_it_be(:upstream) { create(:virtual_registries_container_upstream) }

  let(:user) { upstream.group.first_owner }

  let(:policy) { described_class.new(user, upstream) }

  describe 'delegation' do
    subject { policy }

    it { is_expected.to delegate_to(::VirtualRegistries::Policies::GroupPolicy) }
  end
end
