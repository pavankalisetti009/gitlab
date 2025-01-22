# frozen_string_literal: true

module Search
  module Zoekt
    class UpdateIndexUsedStorageBytesEventWorker
      include Gitlab::EventStore::Subscriber
      include EventWorker
      prepend ::Geo::SkipSecondary

      idempotent!
      deduplicate :until_executed
      defer_on_database_health_signal :gitlab_main, [:zoekt_indices, :zoekt_repositories], 10.minutes

      BATCH_SIZE = 100

      def handle_event(_event)
        Index.with_stale_used_storage_bytes_updated_at.limit(BATCH_SIZE).each do |zoekt_index|
          sum_for_index = 0

          Repository.for_zoekt_indices(zoekt_index).each_batch do |repo_batch|
            sum_for_index += repo_batch.sum(:size_bytes)
          end
          used_storage_bytes = sum_for_index == 0 ? Index::DEFAULT_USED_STORAGE_BYTES : sum_for_index
          zoekt_index.update!(used_storage_bytes: used_storage_bytes, used_storage_bytes_updated_at: Time.zone.now)
        end
        reemit_event
      end

      private

      def reemit_event
        return if Feature.disabled?(:zoekt_reemit_events, Feature.current_request)
        return unless Index.with_stale_used_storage_bytes_updated_at.exists?

        Gitlab::EventStore.publish(Search::Zoekt::UpdateIndexUsedStorageBytesEvent.new(data: {}))
      end
    end
  end
end
