# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::MigrateAiCodeSuggestionEvents, feature_category: :value_stream_management do
  let(:cs_events) { partitioned_table(:ai_code_suggestion_events, by: :timestamp, retain_for: 3.months) }
  let(:ai_usage_events) { partitioned_table(:ai_usage_events, by: :timestamp, retain_for: 3.months) }
  let(:namespaces) { table(:namespaces) }

  let(:migration) do
    described_class.new(
      start_id: cs_events.minimum(:id),
      end_id: cs_events.maximum(:id),
      batch_table: :ai_code_suggestion_events,
      batch_column: :id,
      sub_batch_size: 2,
      pause_ms: 0,
      connection: cs_events.connection
    )
  end

  let!(:organization) { table(:organizations).create!(path: 'org') }
  let!(:namespace1) do
    namespaces.create!(name: 'test_namespace', path: 'test_namespace', organization_id: organization.id)
  end

  let!(:namespace2) do
    namespaces.create!(name: 'test_namespace_2', path: 'test_namespace_2', organization_id: organization.id)
  end

  before do
    stub_feature_flags(disallow_database_ddl_feature_flags: false)
  end

  describe '#perform' do
    context 'when there are ai_code_suggestion_events to migrate', time_travel_to: Time.current.beginning_of_day do
      let!(:event1) do
        cs_events.create!(
          user_id: 1,
          timestamp: Time.current,
          event: 'code_suggestion_shown_in_ide',
          payload: { 'language' => 'ruby' },
          organization_id: organization.id,
          namespace_path: "#{namespace1.id}/"
        )
      end

      let!(:event2) do
        cs_events.create!(
          user_id: 2,
          timestamp: Time.current - 1.day,
          event: 'code_suggestion_shown_in_ide',
          payload: { 'language' => 'java' },
          organization_id: organization.id,
          namespace_path: "#{namespace2.id}/"
        )
      end

      let!(:event3) do
        cs_events.create!(
          user_id: 3,
          timestamp: Time.current - 2.days,
          event: 'code_suggestion_shown_in_ide',
          payload: { 'language' => 'java' },
          organization_id: organization.id,
          namespace_path: nil
        )
      end

      it 'migrates events to ai_usage_events table' do
        expect { migration.perform }.to change { ai_usage_events.count }.by(3)

        expect(ai_usage_events.find_by(user_id: event1.user_id)).to have_attributes(
          timestamp: event1.timestamp,
          organization_id: organization.id,
          created_at: event1.created_at,
          event: event1.event,
          extras: event1.payload,
          namespace_id: namespace1.id
        )

        expect(ai_usage_events.find_by(user_id: event2.user_id)).to have_attributes(
          timestamp: event2.timestamp,
          organization_id: organization.id,
          created_at: event2.created_at,
          event: event2.event,
          extras: event2.payload,
          namespace_id: namespace2.id
        )

        expect(ai_usage_events.find_by(user_id: event3.user_id)).to have_attributes(
          timestamp: event3.timestamp,
          organization_id: organization.id,
          created_at: event3.created_at,
          event: event3.event,
          extras: event3.payload,
          namespace_id: nil
        )
      end

      context 'when there are duplicate events' do
        let!(:event_duplicate) do
          cs_events.create!(
            user_id: event1.user_id,
            timestamp: event1.timestamp,
            event: event1.event,
            payload: event1.payload,
            organization_id: organization.id,
            namespace_path: event1.namespace_path
          )
        end

        it 'does not insert duplicate records' do
          ai_usage_events.create!(
            user_id: event1.user_id,
            timestamp: event1.timestamp,
            event: event1.event,
            extras: {},
            organization_id: organization.id,
            namespace_id: namespace1.id
          )

          expect { migration.perform }.to change { ai_usage_events.count }.by(2)
          expect(ai_usage_events.where(user_id: event1.user_id).first.extras).to eq({})
        end
      end
    end

    context 'when there are no ai_code_suggestion_events' do
      it 'does not migrate any events' do
        expect { migration.perform }.not_to change { ai_usage_events.count }
      end
    end
  end
end
