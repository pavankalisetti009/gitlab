# frozen_string_literal: true

module Search
  module Zoekt
    class RepoToIndexEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Zoekt::EventWorker
      prepend ::Geo::SkipSecondary

      idempotent!

      defer_on_database_health_signal :gitlab_main, [:zoekt_repositories, :zoekt_tasks], 10.minutes

      def handle_event(event)
        return false unless ::Search::Zoekt.licensed_and_indexing_enabled?

        Repository.id_in(event.data[:zoekt_repo_ids]).pending_or_initializing.create_bulk_tasks
      end
    end
  end
end
