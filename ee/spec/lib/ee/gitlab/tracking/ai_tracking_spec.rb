# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Tracking::AiTracking, feature_category: :value_stream_management do
  describe '.track_event', :freeze_time, :click_house do
    subject(:track_event) { described_class.track_event(event_name, event_context) }

    let(:current_user) { build_stubbed(:user) }

    let(:event_context) { { user: current_user } }
    let(:event_name) { 'some_unknown_event' }

    before do
      allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
      stub_feature_flags(code_suggestions_usage_events_in_pg: true)
    end

    context 'for unknown event' do
      let(:event_name) { 'something_unrelated' }

      it { is_expected.to be_nil }
    end

    shared_examples 'common event tracking for' do |model_class|
      let(:expected_event_hash) do
        {
          user: current_user,
          event: event_name
        }
      end

      context 'when clickhouse is disabled for analytics' do
        before do
          allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
        end

        it 'does not store new event to clickhouse' do
          expect_next_instance_of(model_class, expected_event_hash) do |instance|
            expect(instance).not_to receive(:store_to_clickhouse)
          end

          track_event
        end
      end

      it 'stores new event' do
        expect_next_instance_of(model_class, expected_event_hash) do |instance|
          expect(instance).to receive(:store_to_clickhouse).once
        end

        track_event
      end
    end

    context 'for code suggestion event' do
      let(:event_name) { 'code_suggestion_shown_in_ide' }
      let(:expected_event_hash) do
        {
          user: current_user,
          event: event_name
        }
      end

      include_examples 'common event tracking for', Ai::CodeSuggestionEvent

      context 'with clickhouse not available' do
        before do
          allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
        end

        it 'stores event to postgres' do
          expect_next_instance_of(Ai::CodeSuggestionEvent, expected_event_hash) do |instance|
            expect(instance).to receive(:store_to_pg).once
          end

          track_event
        end
      end
    end

    context 'for chat event' do
      let(:event_name) { 'request_duo_chat_response' }
      let(:expected_event_hash) do
        {
          user: current_user,
          event: event_name
        }
      end

      include_examples 'common event tracking for', Ai::DuoChatEvent
    end
  end
end
