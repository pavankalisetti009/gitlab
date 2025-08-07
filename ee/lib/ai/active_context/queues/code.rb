# frozen_string_literal: true

module Ai
  module ActiveContext
    module Queues
      class Code
        include ::ActiveContext::Concerns::Queue

        class << self
          # having a single shard means we have absolute control over the amount of embeddings we generate in one go
          def number_of_shards
            1
          end
        end
      end
    end
  end
end
