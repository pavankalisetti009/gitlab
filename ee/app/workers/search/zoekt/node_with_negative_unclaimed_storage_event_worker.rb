# frozen_string_literal: true

module Search
  module Zoekt
    class NodeWithNegativeUnclaimedStorageEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Worker
      prepend ::Geo::SkipSecondary

      deduplicate :until_executed
      idempotent!

      BATCH_SIZE = 1_000

      def handle_event(event)
        node_ids = event.data[:node_ids]

        return if node_ids.empty?

        Search::Zoekt::Node.negative_unclaimed_storage_bytes.id_in(node_ids).find_each do |node|
          unclaimed_storage_bytes = node.unclaimed_storage_bytes
          next unless unclaimed_storage_bytes < 0

          logger.info(build_structured_payload(
            message: 'Processing node with negative unclaimed storage bytes',
            'zoekt.node_id': node.id,
            'zoekt.unclaimed_storage_bytes': unclaimed_storage_bytes))

          total_reserved_bytes = 0
          index_ids_to_evict = []

          node.indices.find_each do |index|
            total_reserved_bytes += index.reserved_storage_bytes if index.reserved_storage_bytes > 0

            index_ids_to_evict << index.id

            break if total_reserved_bytes >= unclaimed_storage_bytes.abs
          end

          index_ids_to_evict.each_slice(BATCH_SIZE) do |index_ids|
            Gitlab::EventStore.publish(
              Search::Zoekt::IndexToEvictEvent.new(data: { index_ids: index_ids })
            )
          end
        end
      end

      private

      def logger
        @logger ||= ::Search::Zoekt::Logger.build
      end
    end
  end
end
