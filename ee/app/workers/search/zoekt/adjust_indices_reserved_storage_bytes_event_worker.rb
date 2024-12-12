# frozen_string_literal: true

module Search
  module Zoekt
    class AdjustIndicesReservedStorageBytesEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Worker
      prepend ::Geo::SkipSecondary

      deduplicate :until_executed
      idempotent!

      def handle_event(event)
        Index.should_be_reserved_storage_bytes_adjusted.id_in(event.data[:index_ids]).each_batch do |batch|
          batch.each(&:update_reserved_storage_bytes!)
        end
      end
    end
  end
end
