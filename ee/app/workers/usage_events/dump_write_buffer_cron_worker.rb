# frozen_string_literal: true

module UsageEvents
  class DumpWriteBufferCronWorker
    include ApplicationWorker
    include LoopWithRuntimeLimit

    idempotent!
    queue_namespace :cronjob
    data_consistency :delayed
    feature_category :database

    MAX_RUNTIME = 200.seconds
    BATCH_SIZE = 1000

    def perform
      status, inserted_rows = loop_with_runtime_limit(MAX_RUNTIME) { process_next_batch }

      log_extra_metadata_on_done(:result, {
        status: status,
        inserted_rows: inserted_rows
      })
    end

    private

    def process_next_batch
      valid_attributes = next_batch.filter_map do |attributes|
        event = Ai::CodeSuggestionEvent.new(attributes)
        next unless event.valid?

        event.attributes.compact
      end

      res = insert_rows(valid_attributes)

      res ? res.rows.size : 0
    end

    def next_batch
      Ai::UsageEventWriteBuffer.pop(Ai::CodeSuggestionEvent.name, BATCH_SIZE)
    end

    def insert_rows(valid_attributes)
      return if valid_attributes.empty?

      Ai::CodeSuggestionEvent.insert_all(valid_attributes, unique_by: %i[id timestamp])
    end
  end
end
