# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class IncrementalIndexingService < IndexingServiceBase
        def execute
          run_indexer_and_enqueue_ref
        rescue StandardError => e
          update_repository_last_error(e.message)

          raise e
        end

        private

        def update_repository_last_error(message)
          repository.update!(last_error: message)

          log_error("incremental indexing failed", last_error: message)
        end
      end
    end
  end
end
