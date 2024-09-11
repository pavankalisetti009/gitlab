# frozen_string_literal: true

module Search
  module Zoekt
    class OrphanedIndexEventWorker
      include Gitlab::EventStore::Subscriber
      prepend ::Geo::SkipSecondary

      feature_category :global_search
      idempotent!

      def handle_event(event)
        Search::Zoekt::Index.where(id: event.data[:index_ids]).update_all(state: :orphaned) # rubocop:disable CodeReuse/ActiveRecord -- Not relevant
      end
    end
  end
end
