# frozen_string_literal: true

module Search
  module Zoekt
    class IndexOverWatermarkEventWorker
      include Gitlab::EventStore::Subscriber
      prepend ::Geo::SkipSecondary

      feature_category :global_search
      deduplicate :until_executed
      idempotent!

      def handle_event(event)
        watermark_level = watermark_state(event)

        Search::Zoekt::Index.id_in(event.data[:index_ids]).each_batch do |batch|
          batch.update_all(watermark_level: watermark_level)
        end
      end

      private

      def watermark_state(event)
        watermark = event.data[:watermark]
        index_ids_count = event.data[:index_ids].length

        case watermark
        when Search::Zoekt::Index::STORAGE_HIGH_WATERMARK
          log_extra_metadata_on_done(:index_over_high_watermark, index_ids_count)
          :high_watermark_exceeded
        when Search::Zoekt::Index::STORAGE_LOW_WATERMARK
          log_extra_metadata_on_done(:index_over_low_watermark, index_ids_count)
          :low_watermark_exceeded
        else
          raise "Unhandled watermark state: #{watermark}"
        end
      end
    end
  end
end
