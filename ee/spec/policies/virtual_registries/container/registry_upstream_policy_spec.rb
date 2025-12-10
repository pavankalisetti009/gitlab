# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Container::RegistryUpstreamPolicy, feature_category: :virtual_registry do
  let_it_be(:registry_upstream) { create(:virtual_registries_container_registry_upstream) }

  let(:user) { registry_upstream.group.first_owner }

  let(:policy) { described_class.new(user, registry_upstream) }

  describe 'delegation' do
    subject { policy.delegated_policies.values }

    it { is_expected.to have_attributes(size: 1).and be_all(::VirtualRegistries::Policies::GroupPolicy) }
  end
end
