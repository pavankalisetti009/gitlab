# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Analytics::AiUsage::UsageEventsResolver, feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, namespace: group) }
  let(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:usage_event) { create(:ai_usage_event, user: user, namespace: group, timestamp: 2.days.ago) }
  let_it_be(:usage_event2) { create(:ai_usage_event, user: user, namespace: group, timestamp: 1.day.ago) }

  before do
    allow(Ability).to receive(:allowed?)
     .with(user, :read_enterprise_ai_analytics, group)
     .and_return(true)
  end

  describe '#ready' do
    context 'when the unified_ai_events_graphql feature flag is disabled' do
      subject(:resolver) { resolve(described_class, obj: group, ctx: { current_user: user }) }

      before do
        stub_feature_flags(unified_ai_events_graphql: false)
      end

      it { is_expected.to be_an_instance_of(Gitlab::Graphql::Errors::ArgumentError) }
    end

    context 'when resource is a project' do
      subject(:resolver) { resolve(described_class, obj: project, ctx: { current_user: user }) }

      it { is_expected.to be_an_instance_of(Gitlab::Graphql::Errors::ArgumentError) }
    end

    context 'when resource is a subgroup' do
      subject(:resolver) { resolve(described_class, obj: subgroup, ctx: { current_user: user }) }

      it { is_expected.to be_an_instance_of(Gitlab::Graphql::Errors::ArgumentError) }
    end

    context 'when resource is a top-level group' do
      subject(:resolver) { resolve(described_class, obj: group, ctx: { current_user: user }) }

      it { is_expected.to be_truthy }
    end
  end

  describe '#resolve' do
    subject(:resolver) { resolve(described_class, obj: group, ctx: { current_user: user }).to_a }

    it { is_expected.to eq([usage_event2, usage_event]) }

    it 'supports unexpected enums and returns the event with an empty event type' do
      bad_enum_usage_event = create(:ai_usage_event, :with_unknown_event, user: user, namespace: group)

      result = resolver
      expect(result).to eq([bad_enum_usage_event, usage_event2, usage_event])
      expect(result.first.event).to be_nil
    end
  end
end
