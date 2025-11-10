# frozen_string_literal: true

module Search
  module Zoekt
    class TooManyReplicasEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Zoekt::EventWorker
      prepend ::Geo::SkipSecondary

      idempotent!
      defer_on_database_health_signal :gitlab_main, [:zoekt_enabled_namespaces, :zoekt_replicas], 10.minutes
      sidekiq_options retry: true

      BATCH_SIZE = 100

      def handle_event(_event)
        replicas_destroyed_count = destroy_excess_replicas

        log_extra_metadata_on_done(:replicas_destroyed_count, replicas_destroyed_count)

        reemit_event
      end

      private

      # rubocop:disable CodeReuse/ActiveRecord -- ActiveRecord usage is acceptable here
      def destroy_excess_replicas
        replicas_destroyed_count = 0
        processed_count = 0

        EnabledNamespace.each_with_too_many_replicas(batch_size: BATCH_SIZE) do |enabled_namespace|
          break if processed_count >= BATCH_SIZE

          # Preload replicas to avoid N+1 queries
          ActiveRecord::Associations::Preloader.new(
            records: [enabled_namespace],
            associations: :replicas
          ).call

          replicas_destroyed_count += destroy_excess_replicas_for_namespace(enabled_namespace)
          processed_count += 1
        end

        replicas_destroyed_count
      end

      def destroy_excess_replicas_for_namespace(enabled_namespace)
        excess_count = calculate_excess_count(enabled_namespace)
        return 0 if excess_count <= 0

        excess_replica_ids = select_replicas_for_deletion(enabled_namespace.replicas, excess_count)
        Search::Zoekt::Replica.id_in(excess_replica_ids).delete_all
      end

      def calculate_excess_count(enabled_namespace)
        current_count = enabled_namespace.replicas.size
        desired_count = enabled_namespace.number_of_replicas
        current_count - desired_count
      end

      def select_replicas_for_deletion(replicas, excess_count)
        # Sort replicas in memory: pending state first, then by oldest ID (highest to lowest for deletion)
        sorted_replicas = replicas.sort_by { |r| [r.state_before_type_cast, -r.id] }
        sorted_replicas.take(excess_count).map(&:id)
      end
      # rubocop:enable CodeReuse/ActiveRecord

      def reemit_event
        return unless EnabledNamespace.has_any_with_too_many_replicas?

        Gitlab::EventStore.publish(Search::Zoekt::TooManyReplicasEvent.new(data: {}))
      end
    end
  end
end
