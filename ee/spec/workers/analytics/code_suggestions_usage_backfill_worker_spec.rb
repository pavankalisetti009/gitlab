# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CodeSuggestionsUsageBackfillWorker, feature_category: :value_stream_management do
  subject(:worker) { described_class.new }

  let(:event) { Analytics::ClickHouseForAnalyticsEnabledEvent.new(data: { enabled_at: 1.day.ago.iso8601 }) }

  def perform
    worker.perform(event.class.name, event.data)
  end

  context 'when clickhouse is not configured' do
    it 'records disabled status' do
      perform

      expect(worker).to log_extra_metadata_on_done(result: { status: :disabled })
    end
  end

  describe '#perform', :click_house do
    context 'when clickhouse for analytics is not enabled' do
      before do
        stub_application_setting(use_clickhouse_for_analytics: false)
      end

      it 'records disabled status' do
        perform

        expect(worker).to log_extra_metadata_on_done(result: { status: :disabled })
      end
    end

    context 'when clickhouse for analytics is enabled', :freeze_time do
      let_it_be(:organization) { create(:organization, :default) }

      let!(:pg_events) do
        [
          create(:ai_code_suggestion_event, timestamp: 1.day.ago),
          create(:ai_code_suggestion_event, timestamp: 2.days.ago),
          create(:ai_code_suggestion_event, timestamp: 3.days.ago)
        ]
      end

      let(:expected_ch_events) do
        pg_events.map do |e|
          {
            user_id: e[:user_id],
            timestamp: e[:timestamp],
            event: Ai::CodeSuggestionEvent.events['code_suggestion_shown_in_ide'],
            language: 'ruby',
            suggestion_size: 1,
            unique_tracking_id: e[:payload] && e[:payload]['unique_tracking_id'],
            branch_name: 'main',
            namespace_path: '0/'
          }.stringify_keys
        end
      end

      let(:ch_records) do
        ClickHouse::Client.select('SELECT * FROM code_suggestion_usages FINAL ORDER BY timestamp', :main)
      end

      before do
        stub_application_setting(use_clickhouse_for_analytics: true)
      end

      it 'inserts all records to ClickHouse' do
        perform

        expect(ch_records).to match_array(expected_ch_events)
      end

      it "doesn't reschedule itself" do
        expect(described_class).not_to receive(:perform_in)

        perform
      end

      it "doesn't create duplicates when data already exists in CH" do
        clickhouse_fixture(:code_suggestion_usages, [
          { user_id: pg_events.first.user.id, event: 2, timestamp: pg_events.first.timestamp }, # duplicate
          { user_id: pg_events.first.user.id, event: 2, timestamp: pg_events.first.timestamp - 10.days }
        ])

        perform

        expect(ch_records.size).to eq(4)
      end

      context 'when time limit is reached' do
        before do
          stub_const("ClickHouse::SyncStrategies::BaseSyncStrategy::BATCH_SIZE", 1)

          allow_next_instance_of(Gitlab::Metrics::RuntimeLimiter) do |runtime_limiter|
            allow(runtime_limiter).to receive(:over_time?).and_return(false, true)
          end
        end

        it 'stops the processing' do
          perform

          expect(worker).to log_extra_metadata_on_done(
            result: { status: :processed, records_inserted: 2, reached_end_of_table: false }
          )
          expect(ch_records.size).to eq(2)
        end

        it 'reschedules the worker in 1 minute' do
          expect(described_class).to receive(:perform_in).with(1.minute, event.class.name, event.data)

          perform
        end
      end
    end
  end
end
