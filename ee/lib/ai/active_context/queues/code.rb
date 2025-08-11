# frozen_string_literal: true

module Ai
  module ActiveContext
    module Queues
      class Code
        include ::ActiveContext::Concerns::Queue

        COLLECTION_CLASS = ::Ai::ActiveContext::Collections::Code

        DEFAULT_SHARD_LIMIT = 1000

        # having 1 shard means we have absolute control over the amount of embeddings we generate in one go
        DEFAULT_SHARD_COUNT = 1

        class << self
          def number_of_shards
            COLLECTION_CLASS.collection_record&.queue_shard_count || DEFAULT_SHARD_COUNT
          end

          def shard_limit
            COLLECTION_CLASS.collection_record&.queue_shard_limit || DEFAULT_SHARD_LIMIT
          end
        end
      end
    end
  end
end
