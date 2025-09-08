# frozen_string_literal: true

module UsageEvents
  class DumpWriteBufferCronWorker
    include ApplicationWorker
    include ::Analytics::WriteBufferProcessorWorker

    idempotent!
    queue_namespace :cronjob
    data_consistency :delayed
    feature_category :value_stream_management

    MAX_RUNTIME = 200.seconds
    BATCH_SIZE = 1000

    UPSERT_OPTIONS = {
      Ai::DuoChatEvent => { unique_by: %i[id timestamp] },
      Ai::CodeSuggestionEvent => { unique_by: %i[id timestamp] },
      Ai::TroubleshootJobEvent => { unique_by: %i[id timestamp] },
      Ai::UsageEvent => { unique_by: %i[namespace_id user_id event timestamp] }
    }.freeze

    MODELS = UPSERT_OPTIONS.keys.freeze

    EVENT_NAMES_COMPATIBILITY_MAP = {
      'start_agent_platform_session' => 'agent_platform_session_started',
      'create_agent_platform_session' => 'agent_platform_session_created'
    }.freeze

    def perform
      total_inserted_rows = 0

      @current_model = MODELS.first
      current_model_index = 0

      status = loop_with_runtime_limit(MAX_RUNTIME) do
        inserted_rows = process_next_batch
        if inserted_rows == 0
          break :processed if current_model == MODELS.last

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

    def upsert_options(model)
      UPSERT_OPTIONS.fetch(model)
    end

    def prepare_attributes(valid_objects)
      attributes = super

      # Other models have `id` which is unique, and also they will be removed pretty soon.
      return attributes if current_model != Ai::UsageEvent

      uniq_tuple = upsert_options(Ai::UsageEvent)[:unique_by].map(&:to_s)

      # Deduplicate rows with the same uniqueness tuple.
      attributes.group_by { |attr| attr.slice(*uniq_tuple) }.values.map(&:first)
    end

    def compatible_attributes(attributes)
      return attributes unless EVENT_NAMES_COMPATIBILITY_MAP[attributes['event']]

      compatible_attrs = attributes.dup
      compatible_attrs['event'] = EVENT_NAMES_COMPATIBILITY_MAP[compatible_attrs['event']]
      compatible_attrs
    end
  end
end
