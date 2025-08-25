# frozen_string_literal: true

module Search
  module Zoekt
    class RepoToReindexEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Zoekt::EventWorker
      prepend ::Geo::SkipSecondary

      idempotent!

      defer_on_database_health_signal :gitlab_main, [:zoekt_repositories, :zoekt_tasks], 10.minutes

      BATCH_SIZE = 1_000

      def handle_event(event)
        return false unless ::Search::Zoekt.licensed_and_indexing_enabled?

        node_id = event.data[:zoekt_node_id]
        return false if node_id.blank?

        node = Search::Zoekt::Node.find_by_id(node_id)
        return false if node.blank?

        scope = node.zoekt_repositories.should_be_reindexed
        return false if scope.with_pending_or_processing_tasks.exists?

        scope.limit(BATCH_SIZE).create_bulk_tasks

        repositories_reindexed_count = scope.limit(BATCH_SIZE).count
        log_extra_metadata_on_done(:repositories_reindexed_count, repositories_reindexed_count)
      end
    end
  end
end
