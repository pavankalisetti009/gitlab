# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class InitialIndexingService < IndexingServiceBase
        def execute
          update_repository_state!(:code_indexing_in_progress)

          run_indexer_and_enqueue_ref

          update_repository_state!(:embedding_indexing_in_progress)
        rescue StandardError => e
          update_repository_state!(:failed, last_error: e.message)

          raise e
        end

        private

        def update_repository_state!(state, extra_params = {})
          repository.update!(state: state, **extra_params)

          if state == :failed
            log_error(state.to_s, last_error: extra_params[:last_error])
          else
            log_info(state.to_s)
          end
        end
      end
    end
  end
end
