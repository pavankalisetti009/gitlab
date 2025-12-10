# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::VirtualRegistries::Cleanup::PolicyResolver, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:policy) { create(:virtual_registries_cleanup_policy, group: group) }
  let_it_be(:policy2) { create(:virtual_registries_cleanup_policy) }

  let(:feature_enabled) { true }
  let(:user_has_access) { true }
  let(:args) { {} }

  subject(:resolve_policy) do
    resolve(described_class, obj: group, args: args, ctx: { current_user: current_user })
  end

  before do
    allow(::VirtualRegistries::Packages::Maven).to receive_messages(
      feature_enabled?: feature_enabled,
      user_has_access?: user_has_access
    )
  end

  specify do
    expect(described_class).to have_nullable_graphql_type(
      ::Types::VirtualRegistries::Cleanup::PolicyType
    )
  end

  context 'when unauthorized' do
    let(:user_has_access) { false }

    it { is_expected.to be_nil }
  end

  context 'when authorized' do
    context 'when maven virtual registry is available' do
      it { is_expected.to eq(policy) }
    end

    context 'when maven virtual registry is unavailable' do
      let(:feature_enabled) { false }

      it { is_expected.to be_nil }
    end

    context 'when virtual_registry_cleanup_policies is unavailable' do
      before do
        stub_feature_flags(virtual_registry_cleanup_policies: false)
      end

      it { is_expected.to be_nil }
    end
  end
end
