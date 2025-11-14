# frozen_string_literal: true

module Ai
  module ActiveContext
    class MetricsUpdateService
      def execute
        gauge = Gitlab::Metrics.gauge(
          :active_context_queue_size,
          'Number of items in each ActiveContext queue',
          { queue_name: nil, shard: nil }
        )

        ::ActiveContext::Queues.queue_counts.each do |hash|
          gauge.set({ queue_name: hash[:queue_name], shard: hash[:shard] }, hash[:count])
        end
      end
    end
  end
end
