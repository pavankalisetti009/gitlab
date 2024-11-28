# frozen_string_literal: true

module Search
  module Zoekt
    class RepoToIndexEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Worker
      prepend ::Geo::SkipSecondary

      idempotent!

      def handle_event(event)
        return false unless ::Search::Zoekt.enabled?

        Repository.id_in(event.data[:zoekt_repo_ids]).pending_or_initializing.create_bulk_tasks
      end
    end
  end
end
