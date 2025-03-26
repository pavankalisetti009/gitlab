# frozen_string_literal: true

module Vulnerabilities
  module NamespaceStatistics
    class AdjustmentService
      TooManyNamespacesError = Class.new(StandardError)

      UPSERT_SQL = <<~SQL
        INSERT INTO vulnerability_namespace_statistics
          (total, info, unknown, low, medium, high, critical, traversal_ids, namespace_id, created_at, updated_at)
          (%{stats_sql})
        ON CONFLICT (namespace_id)
        DO UPDATE SET
          total = EXCLUDED.total,
          info = EXCLUDED.info,
          unknown = EXCLUDED.unknown,
          low = EXCLUDED.low,
          medium = EXCLUDED.medium,
          high = EXCLUDED.high,
          critical = EXCLUDED.critical,
          updated_at = EXCLUDED.updated_at,
          traversal_ids = EXCLUDED.traversal_ids
      SQL

      STATS_SQL = <<~SQL
        WITH namespace_data (namespace_id, traversal_ids, next_traversal_id) AS (
            %{with_values}
        )
        SELECT
          SUM(total) AS total,
          SUM(info) AS info,
          SUM(unknown) AS unknown,
          SUM(low) AS low,
          SUM(medium) AS medium,
          SUM(high) AS high,
          SUM(critical) AS critical,
          namespace_data.traversal_ids as traversal_ids,
          namespace_data.namespace_id as namespace_id,
          now() AS created_at,
          now() AS updated_at
        FROM vulnerability_statistics, namespace_data
        WHERE vulnerability_statistics.archived = FALSE
          AND vulnerability_statistics.traversal_ids >= namespace_data.traversal_ids
          AND vulnerability_statistics.traversal_ids < namespace_data.next_traversal_id
        GROUP BY namespace_data.traversal_ids, namespace_id
      SQL

      MAX_NAMESPACES = 1_000

      def self.execute(namespace_ids)
        new(namespace_ids).execute
      end

      def initialize(namespace_ids)
        if namespace_ids.size > MAX_NAMESPACES
          raise TooManyNamespacesError, "Cannot adjust namespace statistics for more than #{MAX_NAMESPACES} namespaces"
        end

        @namespace_ids = namespace_ids
      end

      def execute
        return if @namespace_ids.empty?

        @namespace_ids.each_slice(100) do |namespace_ids_batch|
          namespace_data = with_namespace_data(namespace_ids_batch)
          next if namespace_data.blank?

          Gitlab::Database::SecApplicationRecord.connection.execute(upsert_sql(namespace_data))
        end
      end

      private

      def upsert_sql(namespace_data)
        format(UPSERT_SQL, stats_sql: stats_sql(namespace_data))
      end

      def stats_sql(namespace_data)
        format(STATS_SQL, with_values: namespace_data)
      end

      def with_namespace_data(namespace_ids_batch)
        return unless namespace_ids_batch.present?

        # rubocop:disable CodeReuse/ActiveRecord -- Specific order and use case
        namespace_values = Namespace.without_deleted.without_project_namespaces
          .id_in(namespace_ids_batch)
          .limit(namespace_ids_batch.length)
          .pluck(:id, :traversal_ids)
        # rubocop:enable CodeReuse/ActiveRecord

        return unless namespace_values.present?

        values = namespace_values.map do |row|
          traversal_ids = row[1]
          next_traversal_ids = traversal_ids.dup
          next_traversal_ids[-1] += 1

          [
            row[0],
            Arel.sql("ARRAY#{traversal_ids}::bigint[]"),
            Arel.sql("ARRAY#{next_traversal_ids}::bigint[]")
          ]
        end

        Arel::Nodes::ValuesList.new(values).to_sql
      end
    end
  end
end
