# frozen_string_literal: true

module Search
  module Zoekt
    class IndexWatermarkChangedEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Worker
      prepend ::Geo::SkipSecondary

      deduplicate :until_executed
      idempotent!

      def handle_event(event)
        watermark_level = event.data[:watermark_level]
        index_ids = event.data[:index_ids]

        return unless watermark_level.present? && index_ids.present?

        Search::Zoekt::Index.id_in(event.data[:index_ids]).each_batch do |batch|
          batch.each(&:update_reserved_storage_bytes!)
        end
      end
    end
  end
end
