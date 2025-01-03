# frozen_string_literal: true

module Search
  module Zoekt
    class OrphanedIndexEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Zoekt::EventWorker
      prepend ::Geo::SkipSecondary

      idempotent!

      defer_on_database_health_signal :gitlab_main, [:zoekt_indices], 10.minutes

      def handle_event(event)
        Search::Zoekt::Index.where(id: event.data[:index_ids]).update_all(state: :orphaned) # rubocop:disable CodeReuse/ActiveRecord -- Not relevant
      end
    end
  end
end
