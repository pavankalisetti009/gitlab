# frozen_string_literal: true

module Vulnerabilities
  module NamespaceStatistics
    class ScheduleWorker
      include ApplicationWorker

      idempotent!
      data_consistency :sticky

      # rubocop:disable Scalability/CronWorkerContext -- This worker doesn't have a scoped context.
      include CronjobQueue

      # rubocop:enable Scalability/CronWorkerContext

      feature_category :security_asset_inventories

      BATCH_SIZE = 500
      DELAY_INTERVAL = 30.seconds.to_i

      # Only processes namespaces with matching vulnerability statistics instead of all group namespaces
      def perform
        pending_ids = []
        index = 0

        Namespace.without_deleted.group_namespaces.each_batch(of: BATCH_SIZE) do |relation|
          # rubocop:disable CodeReuse/ActiveRecord -- Specific order and use case
          namespace_map = relation.pluck(:id, :traversal_ids).to_h
          traversal_arrays = format_for_sql_query(namespace_map.values)

          # rubocop:disable Rails/WhereEquals -- Hash syntax treats array as one value
          vulnerable_traversals = Vulnerabilities::Statistic.unarchived
            .where('traversal_ids IN (?)', traversal_arrays).pluck(:traversal_ids).uniq
          # rubocop:enable Rails/WhereEquals
          # rubocop:enable CodeReuse/ActiveRecord

          matching_ids = extract_matching_namespace_ids(namespace_map, vulnerable_traversals)
          pending_ids.concat(matching_ids)
          next unless pending_ids.length >= BATCH_SIZE

          schedule_batch_processing(index, pending_ids.shift(BATCH_SIZE))
          index += 1
        end

        schedule_batch_processing(1, pending_ids) unless pending_ids.empty?
      end

      def format_for_sql_query(traversal_ids_collection)
        traversal_ids_collection.map do |traversal_ids|
          "{#{traversal_ids.join(',')}}"
        end
      end

      def extract_matching_namespace_ids(namespace_map, vulnerable_traversals)
        namespace_map.select do |_, traversal_ids|
          vulnerable_traversals.include?(traversal_ids)
        end.keys
      end

      def schedule_batch_processing(index, batch_ids)
        NamespaceStatistics::AdjustmentWorker.perform_in(index * DELAY_INTERVAL, batch_ids)
      end
    end
  end
end
