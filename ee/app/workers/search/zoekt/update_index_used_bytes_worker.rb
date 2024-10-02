# frozen_string_literal: true

module Search
  module Zoekt
    class UpdateIndexUsedBytesWorker
      include Gitlab::EventStore::Subscriber
      prepend ::Geo::SkipSecondary

      feature_category :global_search
      urgency :low
      idempotent!

      def handle_event(event)
        repo = ::Search::Zoekt::Repository.find_by_id(event.data[:zoekt_repository_id])
        return if repo.nil?

        repo.zoekt_index.update_used_storage_bytes!
      end
    end
  end
end
