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

      def handle_event(event)
        index_ids = event.data[:index_ids]

        return unless index_ids.present?

        Search::Zoekt::Index.id_in(index_ids).each_batch do |batch|
          ::Search::Zoekt::Replica.id_in(batch.select(:zoekt_replica_id)).delete_all
        end
      end
    end
  end
end
