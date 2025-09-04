# frozen_string_literal: true

module Search
  module Zoekt
    class RepoToReindexEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Zoekt::EventWorker
      prepend ::Geo::SkipSecondary

      idempotent!

      defer_on_database_health_signal :gitlab_main, [:zoekt_repositories, :zoekt_tasks], 10.minutes

      LIMIT = 1_000

      def handle_event(event)
        return false unless ::Search::Zoekt.licensed_and_indexing_enabled?

        node_id = event.data[:zoekt_node_id]
        return false if node_id.blank?

        node = Search::Zoekt::Node.for_search.find_by_id(node_id)
        return false if node.blank?

        scope = node.zoekt_repositories.should_be_reindexed
        reindexing_repository_ids = scope.with_pending_or_processing_tasks.pluck_primary_key
        remaining_limit = LIMIT - reindexing_repository_ids.count

        return false if remaining_limit <= 0

        # Skip repositories that already have pending or processing tasks
        final_scope = scope.id_not_in(reindexing_repository_ids).limit(remaining_limit)

        final_scope.create_bulk_tasks

        repositories_reindexed_count = final_scope.count
        log_extra_metadata_on_done(:repositories_reindexed_count, repositories_reindexed_count)
      end
    end
  end
end
