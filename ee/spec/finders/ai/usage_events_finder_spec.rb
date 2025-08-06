# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::UsageEventsFinder, feature_category: :value_stream_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:user) { create(:user, namespace: group) }

  let(:allowed) { false }

  subject(:finder) { described_class.new(user, resource: group).execute }

  describe '#execute' do
    before do
      allow(Ability).to receive(:allowed?)
        .with(user, :read_enterprise_ai_analytics, group)
        .and_return(allowed)
    end

    context 'when user cannot read AI Usage events' do
      let_it_be(:usage_event) do
        create(:ai_usage_event, user: user, namespace: group)
      end

      it 'returns an empty relation' do
        expect(finder).to be_empty
      end
    end

    context 'when user can read AI Usage events' do
      let(:allowed) { true }

      context 'when there are not events' do
        it 'returns an empty relation' do
          expect(finder).to be_empty
        end
      end

      context 'when there are events' do
        let_it_be(:usage_event) do
          create(:ai_usage_event, user: user, namespace: group)
        end

        it 'returns an array with ai usage events' do
          expect(finder).to contain_exactly(usage_event)
        end
      end

      context 'with keyset pagination' do
        it 'uses QueryBuilder with correct parameters' do
          expect(::Gitlab::Pagination::Keyset::InOperatorOptimization::QueryBuilder)
            .to receive(:new)
            .with(
              scope: be_a(ActiveRecord::Relation),
              array_scope: be_a(ActiveRecord::Relation),
              array_mapping_scope: Ai::UsageEvent.method(:in_optimization_array_mapping_scope),
              finder_query: Ai::UsageEvent.method(:in_optimization_finder_query)
            )
            .and_call_original

          finder
        end

        it 'applies the default limit of 100' do
          # Create a few events to test the limit
          create_list(:ai_usage_event, 3, user: user, namespace: group)

          result = finder
          expect(result.limit_value).to eq(100)
        end

        it 'orders by timestamp desc' do
          # Create events with different timestamps
          old_event = create(:ai_usage_event, user: user, namespace: group, timestamp: 2.days.ago)
          new_event = create(:ai_usage_event, user: user, namespace: group, timestamp: 1.day.ago)

          result = finder.to_a
          expect(result.first).to eq(new_event)
          expect(result.last).to eq(old_event)
        end

        it 'includes events from descendant namespaces' do
          parent_event = create(:ai_usage_event, user: user, namespace: group)
          child_event = create(:ai_usage_event, user: user, namespace: subgroup)
          other_namespace_event = create(:ai_usage_event, user: user, namespace: create(:group))

          result = finder
          expect(result).to contain_exactly(parent_event, child_event)
          expect(result).not_to include(other_namespace_event)
        end

        it 'ignores events with future timestamps' do
          # Create events with different timestamps
          old_event = create(:ai_usage_event, user: user, namespace: group, timestamp: 2.days.ago)
          create(:ai_usage_event, user: user, namespace: group, timestamp: 2.days.from_now)

          result = finder.to_a
          expect(result).to contain_exactly(old_event)
        end
      end

      context 'when retrieving an unrecognized enum' do
        let_it_be(:usage_event) do
          create(:ai_usage_event, :with_unknown_event, user: user, namespace: group)
        end

        it 'returns an array with the event and an empty event type' do
          result = finder
          expect(result).to contain_exactly(usage_event)
          expect(usage_event.event).to be_nil
        end
      end
    end
  end
end
