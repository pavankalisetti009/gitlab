# frozen_string_literal: true

module Search
  module Zoekt
    class IndexToEvictEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Zoekt::EventWorker
      prepend ::Geo::SkipSecondary

      deduplicate :until_executed
      idempotent!

      defer_on_database_health_signal :gitlab_main, [:zoekt_indices, :zoekt_replicas], 10.minutes

      BATCH_SIZE = 1000

      def handle_event(_event)
        indices = Search::Zoekt::Index.should_be_evicted.limit(BATCH_SIZE)
        return unless indices.exists?

        deleted_count = ::Search::Zoekt::Replica.id_in(indices.select(:zoekt_replica_id)).delete_all

        log_extra_metadata_on_done(:replicas_deleted_count, deleted_count)
      end
    end
  end
end
