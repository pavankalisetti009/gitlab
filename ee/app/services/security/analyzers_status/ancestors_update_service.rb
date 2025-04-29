# frozen_string_literal: true

module Security
  module AnalyzersStatus
    class AncestorsUpdateService
      # This expands the traversal ids.
      # For each project's diff, we should update entries for all parent groups in the hierarchy
      EXPANDED_PATHS_SQL = <<~SQL
        SELECT
          -- For each position in the array, select all elements up to that position
          d.traversal_ids[i] AS namespace_id,
          d.traversal_ids[1:i] AS traversal_ids,
          d.analyzer_type,
          d.success,
          d.failure
        FROM
          diffs d,
          generate_series(1, array_length(d.traversal_ids, 1)) AS i
      SQL

      AGGREGATED_PATHS_SQL = <<~SQL
        SELECT
          namespace_id,
          traversal_ids,
          analyzer_type,
          SUM(success) AS success,
          SUM(failure) AS failure
        FROM expanded_paths
        GROUP BY namespace_id, traversal_ids, analyzer_type
      SQL

      UPSERT_SQL = <<~SQL
        WITH diffs(namespace_id, traversal_ids, analyzer_type, success, failure) AS (
          %{diffs_input}
        ), expanded_paths AS (
          %{expanded_paths_sql}
        ), aggregated_paths AS (
          %{aggregated_paths_sql}
        )

        INSERT INTO analyzer_namespace_statuses AS ans (
          namespace_id, traversal_ids, analyzer_type, success, failure, created_at, updated_at
        )
        SELECT
          ap.namespace_id,
          ap.traversal_ids,
          ap.analyzer_type,
          ap.success,
          ap.failure,
          now(),
          now()
        FROM aggregated_paths ap
        ON CONFLICT (namespace_id, analyzer_type)
        DO UPDATE SET
          traversal_ids = excluded.traversal_ids,
          success = GREATEST(ans.success + excluded.success, 0),
          failure = GREATEST(ans.failure + excluded.failure, 0),
          updated_at = excluded.updated_at
      SQL

      def self.execute(project, diffs)
        new(project, diffs).execute
      end

      def initialize(project, diffs)
        @diffs = diffs
        @project = project
      end

      def execute
        return if filtered_diffs.blank?

        update_statistics_based_on_diff
      end

      private

      attr_reader :diffs, :project

      delegate :connection, to: AnalyzerProjectStatus, private: true

      def filtered_diffs
        @filtered_diffs ||= diffs&.select { |_, stats| valid_stats?(stats) }
      end

      def valid_stats?(stats)
        stats.present? && (stats["success"].to_i != 0 || stats["failed"].to_i != 0)
      end

      def update_statistics_based_on_diff
        connection.execute(upsert_sql)
      end

      def upsert_sql
        format(
          UPSERT_SQL,
          diffs_input: diffs_input_values,
          expanded_paths_sql: EXPANDED_PATHS_SQL,
          aggregated_paths_sql: AGGREGATED_PATHS_SQL
        )
      end

      def diffs_input_values
        values = []

        filtered_diffs.each do |analyzer_type, stats|
          success = stats["success"] || 0
          failure = stats["failed"] || 0

          values << [
            project.namespace_id,
            Arel.sql("'{#{project.namespace.traversal_ids.join(',')}}'::bigint[]"),
            Enums::Security.analyzer_types[analyzer_type],
            success,
            failure
          ]
        end

        Arel::Nodes::ValuesList.new(values).to_sql
      end
    end
  end
end
