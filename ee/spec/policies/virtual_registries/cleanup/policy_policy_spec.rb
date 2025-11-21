# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Cleanup::PolicyPolicy, feature_category: :virtual_registry do
  let_it_be(:cleanup_policy) { create(:virtual_registries_cleanup_policy) }

  let(:user) { cleanup_policy.group.first_owner }

  let(:policy) { described_class.new(user, cleanup_policy) }

  describe 'delegation' do
    subject { policy }

    it { is_expected.to delegate_to(::VirtualRegistries::Policies::GroupPolicy) }
  end
end
