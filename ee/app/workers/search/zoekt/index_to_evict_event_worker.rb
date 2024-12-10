# frozen_string_literal: true

module Search
  module Zoekt
    class IndexToEvictEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Worker
      prepend ::Geo::SkipSecondary

      deduplicate :until_executed
      idempotent!

      def handle_event(event)
        index_ids = event.data[:index_ids]

        return unless index_ids.present?

        Search::Zoekt::Index.critical_watermark_exceeded.id_in(index_ids).each_batch do |batch|
          ::Search::Zoekt::Replica.for_namespace(batch.select(:namespace_id)).each_batch do |batch|
            batch.delete_all
          end
        end
      end
    end
  end
end
