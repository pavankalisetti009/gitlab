# frozen_string_literal: true

module Search
  module Zoekt
    class RepoToReindexEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Zoekt::EventWorker
      prepend ::Geo::SkipSecondary

      idempotent!

      defer_on_database_health_signal :gitlab_main, [:zoekt_repositories, :zoekt_tasks], 10.minutes

      BATCH_SIZE = 500

      def handle_event(_event)
        return false unless ::Search::Zoekt.licensed_and_indexing_enabled?
        return false if Search::Zoekt::Repository.should_be_reindexed.with_pending_or_processing_tasks.exists?

        Repository.should_be_reindexed.limit(BATCH_SIZE).create_bulk_tasks
      end
    end
  end
end
