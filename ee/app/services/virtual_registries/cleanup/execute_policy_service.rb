# frozen_string_literal: true

module VirtualRegistries
  module Cleanup
    class ExecutePolicyService
      UPSTREAM_CLASSES = {
        maven: ::VirtualRegistries::Packages::Maven::Upstream,
        container: ::VirtualRegistries::Container::Upstream
      }.freeze
      BATCH_SIZE = 250

      def initialize(policy)
        @policy = policy
        @counts = UPSTREAM_CLASSES.transform_values { { deleted_entries_count: 0, deleted_size: 0 } }
      end

      def execute
        return ServiceResponse.error(message: 'Cleanup policy is required') unless policy

        UPSTREAM_CLASSES.each do |key, klass|
          process_upstream_class(key, klass)
        end

        ServiceResponse.success(payload: counts)
      rescue StandardError => e
        ServiceResponse.error(message: "Failed to execute cleanup policy: #{e.message}")
      end

      private

      attr_reader :policy, :counts

      def process_upstream_class(key, klass)
        klass.select(:id).for_group(policy.group_id).find_each do |upstream|
          process_upstream(upstream, key)
        end
      end

      def process_upstream(upstream, key)
        upstream
          .default_cache_entries
          .requiring_cleanup(policy.keep_n_days_after_download)
          .each_batch(of: BATCH_SIZE, column: :relative_path) do |batch|
          result = mark_batch_for_destruction(batch)

          counts[key][:deleted_entries_count] += result.size
          counts[key][:deleted_size] += result.sum
        end
      end

      def mark_batch_for_destruction(batch)
        sql = build_update_sql(batch)
        batch.connection.query_values(sql)
      end

      def build_update_sql(batch)
        table = batch.arel_table
        update_manager = build_update_manager(batch, table)
        returning = Arel::Nodes::Grouping.new(table[:size])

        "#{batch.connection.to_sql(update_manager)} RETURNING #{returning.to_sql}"
      end

      def build_update_manager(batch, table)
        Arel::UpdateManager.new(table).tap do |manager|
          manager.set([
            [table[:status], batch.model.statuses[:pending_destruction]],
            [table[:relative_path], Arel.sql("relative_path || '/deleted/' || gen_random_uuid()")],
            [table[:updated_at], Time.current]
          ])
          manager.wheres = batch.arel.constraints
        end
      end
    end
  end
end
