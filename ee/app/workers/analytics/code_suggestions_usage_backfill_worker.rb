# frozen_string_literal: true

module Analytics
  # Backfills usage data to ClickHouse from Postgres when ClickHouse was enabled for analytics
  class CodeSuggestionsUsageBackfillWorker < ClickHouse::SyncStrategies::BaseSyncStrategy
    include Gitlab::EventStore::Subscriber

    data_consistency :sticky
    feature_category :value_stream_management
    urgency :low
    idempotent!

    RESCHEDULING_DELAY = 1.minute

    def handle_event(event)
      execute.tap do |result|
        log_extra_metadata_on_done(:result, result)

        if !result[:reached_end_of_table] && result[:status] != :disabled
          self.class.perform_in(RESCHEDULING_DELAY, event.class.name, event.data.deep_stringify_keys.to_h)
        end
      end
    end

    private

    def projections
      @projections ||= [
        "EXTRACT(epoch FROM timestamp) AS casted_timestamp",
        :user_id,
        "event as raw_event",
        :namespace_path,
        :payload
      ]
    end

    def csv_mapping
      @csv_mapping ||= {
        user_id: :user_id,
        timestamp: :casted_timestamp,
        event: :raw_event,
        namespace_path: :namespace_path,
        suggestion_size: :suggestion_size,
        language: :language,
        branch_name: :branch_name,
        unique_tracking_id: :unique_tracking_id
      }
    end

    def transform_row(row)
      row.attributes.merge(row['payload']).symbolize_keys.slice(*csv_mapping.values)
    end

    def insert_query
      <<~SQL.squish
          INSERT INTO code_suggestion_usages (#{csv_mapping.keys.join(', ')})
          SETTINGS async_insert=1, wait_for_async_insert=1 FORMAT CSV
      SQL
    end

    def model_class
      ::Ai::CodeSuggestionEvent
    end

    def enabled?
      super && Gitlab::ClickHouse.globally_enabled_for_analytics?
    end
  end
end
