# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::UsageEventsFinder, feature_category: :value_stream_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:user) { create(:user, namespace: group) }

  let(:allowed) { false }

  let_it_be(:to) { Time.current }
  let_it_be(:from) { 20.days.ago(to) }

  let(:finder_params) do
    { resource: group, from: from, to: to }
  end

  subject(:finder) { described_class.new(user, **finder_params).execute }

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
        let_it_be(:event1) do
          create(:ai_usage_event, user: user, namespace: group,
            timestamp: 2.days.ago, event: 'code_suggestion_shown_in_ide')
        end

        let_it_be(:event2) do
          create(:ai_usage_event, user: user, namespace: group,
            timestamp: 1.day.ago, event: 'code_suggestion_accepted_in_ide')
        end

        let_it_be(:too_old_event) do
          create(:ai_usage_event, user: user, namespace: group, timestamp: from - 1.day)
        end

        let_it_be(:too_new_event) do
          create(:ai_usage_event, user: user, namespace: group, timestamp: to + 1.day)
        end

        it 'returns an array with ai usage events matching time range filter' do
          expect(finder).to contain_exactly(event1, event2)
        end

        it 'orders by timestamp desc' do
          expect(finder.to_a).to eq([event2, event1])
        end

        it 'includes events from descendant namespaces' do
          child_event = create(:ai_usage_event, user: user, namespace: subgroup, timestamp: to)
          _other_namespace_event = create(:ai_usage_event, user: user, namespace: create(:group), timestamp: to)

          expect(finder).to contain_exactly(event1, event2, child_event)
        end

        context 'when event names filter specified' do
          let(:finder_params) do
            super().merge(events: ['code_suggestion_accepted_in_ide'])
          end

          it 'returns only events with corresponding event name' do
            expect(finder.to_a).to eq([event2])
          end
        end

        context 'when event names filter is empty' do
          let(:finder_params) do
            super().merge(events: [])
          end

          it "doesn't apply any event filtering" do
            expect(finder.to_a).to match_array([event1, event2])
          end
        end
      end

      context 'when retrieving an unrecognized enum' do
        let_it_be(:usage_event) do
          create(:ai_usage_event, :with_unknown_event, user: user, namespace: group, timestamp: to)
        end

        it 'returns an array with the event and an empty event type' do
          result = finder
          expect(result).to contain_exactly(usage_event)
          expect(result.first.event).to be_nil
        end
      end
    end
  end
end
