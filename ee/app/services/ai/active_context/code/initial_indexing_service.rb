# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class InitialIndexingService
        def self.execute(repository)
          new(repository).execute
        end

        def initialize(repository)
          @repository = repository
        end

        def execute
          repository.code_indexing_in_progress!

          last_indexed_id = nil

          run_indexer! do |indexed_id|
            enqueue_refs!([indexed_id])
            last_indexed_id = indexed_id
          end

          repository.embedding_indexing_in_progress!
          set_highest_enqueued_item!(last_indexed_id) if last_indexed_id
        rescue StandardError => e
          repository.update!(state: :failed, last_error: e.message)
          raise e
        end

        private

        attr_reader :repository

        def run_indexer!(&block)
          Indexer.run!(repository, &block)
        end

        def enqueue_refs!(ids)
          ::Ai::ActiveContext::Collections::Code.track_refs!(hashes: ids, routing: repository.project_id)
        end

        def set_highest_enqueued_item!(item)
          repository.update!(
            initial_indexing_last_queued_item: item,
            indexed_at: Time.current
          )
        end
      end
    end
  end
end
