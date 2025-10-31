# frozen_string_literal: true

module VirtualRegistries
  module Cleanup
    class ExecutePolicyService
      UPSTREAM_CLASSES = {
        maven: ::VirtualRegistries::Packages::Maven::Upstream,
        container: ::VirtualRegistries::Container::Upstream
      }.freeze
      BATCH_SIZE = 250
      DELETION_REGEX = %r{/deleted/.*}

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
          log_audit_events(upstream, batch.model, result.map(&:last))

          counts[key][:deleted_entries_count] += result.size
          counts[key][:deleted_size] += result.sum(&:first)
        end
      end

      def mark_batch_for_destruction(batch)
        sql = build_update_sql(batch)
        batch.connection.select_rows(sql)
      end

      def build_update_sql(batch)
        update_manager = build_update_manager(batch)
        "#{batch.connection.to_sql(update_manager)} RETURNING size, relative_path"
      end

      def build_update_manager(batch)
        table = batch.arel_table
        Arel::UpdateManager.new(table).tap do |manager|
          manager.set([
            [table[:status], batch.model.statuses[:pending_destruction]],
            [table[:relative_path], Arel.sql("relative_path || '/deleted/' || gen_random_uuid()")],
            [table[:updated_at], Time.current]
          ])
          manager.wheres = batch.arel.constraints
        end
      end

      def log_audit_events(upstream, model, destroyed_paths)
        return if destroyed_paths.empty?

        event_name = "#{model.model_name.param_key}_deleted"
        entries = destroyed_paths.map do |path|
          model.new(group: policy.group, upstream: upstream, relative_path: path.sub(DELETION_REGEX, ''))
        end

        ::VirtualRegistries::CreateAuditEventsService.new(entries:, event_name:).execute
      end
    end
  end
end
