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

    MODELS = [Ai::DuoChatEvent, Ai::CodeSuggestionEvent].freeze

    def perform
      total_inserted_rows = 0

      @current_model = MODELS.first
      current_model_index = 0

      status = loop_with_runtime_limit(MAX_RUNTIME) do
        inserted_rows = process_next_batch
        if inserted_rows == 0
          break :processed if @current_model == MODELS.last

          current_model_index += 1
          @current_model = MODELS[current_model_index]
        end

        total_inserted_rows += inserted_rows
      end

      log_extra_metadata_on_done(:result, {
        status: status,
        inserted_rows: total_inserted_rows
      })
    end

    private

    def process_next_batch
      valid_attributes = next_batch.filter_map do |attributes|
        event = @current_model.new(attributes)
        next unless event.valid?

        event.attributes.compact
      end

      res = @current_model.insert_all(valid_attributes, unique_by: %i[id timestamp]) unless valid_attributes.empty?

      res ? res.rows.size : 0
    end

    def next_batch
      Ai::UsageEventWriteBuffer.pop(@current_model.name, BATCH_SIZE)
    end
  end
end
