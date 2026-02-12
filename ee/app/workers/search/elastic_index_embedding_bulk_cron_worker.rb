# frozen_string_literal: true

module Search
  class ElasticIndexEmbeddingBulkCronWorker # rubocop:disable Scalability/IdempotentWorker -- worker has deduplication
    include ::Elastic::BulkCronWorker
    include Search::Elastic::Concerns::RateLimiter

    urgency :low
    data_consistency :sticky
    defer_on_database_health_signal :gitlab_main

    def perform(shard_number = nil)
      # No-op: This worker has been deprecated and no longer performs any work
    end
  end
end
