# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class IndexingServiceBase
        include Gitlab::Loggable

        def self.execute(repository)
          new(repository).execute
        end

        def initialize(repository)
          @repository = repository
        end

        private

        attr_reader :repository

        def run_indexer_and_enqueue_ref
          last_indexed_id = nil

          run_indexer! do |indexed_id|
            enqueue_refs!([indexed_id])
            last_indexed_id = indexed_id
          end

          set_highest_enqueued_item!(last_indexed_id) if last_indexed_id
        end

        def run_indexer!(&block)
          Indexer.run!(repository, &block)
        end

        def enqueue_refs!(ids)
          ::Ai::ActiveContext::Collections::Code.track_refs!(hashes: ids, routing: repository.project_id)
        end

        def set_highest_enqueued_item!(item_id)
          repository.update!(
            initial_indexing_last_queued_item: item_id,
            indexed_at: Time.current
          )

          log_info(
            'set_highest_enqueued_item',
            initial_indexing_last_queued_item: item_id
          )
        end

        def log_info(message, extra_params = {})
          logger.info(build_log_payload(message, extra_params))
        end

        def log_error(message, extra_params = {})
          logger.error(build_log_payload(message, extra_params))
        end

        def build_log_payload(message, extra_params = {})
          params = {
            message: message,
            ai_active_context_code_repository_id: repository.id,
            project_id: repository.project_id
          }.merge(extra_params)

          build_structured_payload(**params)
        end

        def logger
          @logger ||= ::ActiveContext::Config.logger
        end
      end
    end
  end
end
