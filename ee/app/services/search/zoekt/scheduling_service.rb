# frozen_string_literal: true

module Search
  module Zoekt
    class SchedulingService
      include Gitlab::Loggable

      TASKS = %i[
        adjust_indices_reserved_storage_bytes
        auto_index_self_managed
        dot_com_rollout
        eviction
        index_mismatched_watermark_check
        index_should_be_marked_as_orphaned_check
        index_to_delete_check
        indices_to_evict_check
        initial_indexing
        lost_nodes_check
        mark_indices_as_ready
        node_assignment
        node_with_negative_unclaimed_storage_bytes_check
        remove_expired_subscriptions
        repo_should_be_marked_as_orphaned_check
        repo_to_delete_check
        repo_to_index_check
        update_index_used_bytes
        update_replica_states
      ].freeze

      BUFFER_FACTOR = 3

      DOT_COM_ROLLOUT_TARGET_BYTES = 450.gigabytes
      DOT_COM_ROLLOUT_LIMIT = 2000
      DOT_COM_ROLLOUT_SEARCH_LIMIT = 500

      INITIAL_INDEXING_LIMIT = 10

      attr_reader :task

      def self.execute!(task)
        execute(task, without_cache: true)
      end

      def self.execute(task, without_cache: false)
        instance = new(task)

        Gitlab::Redis::SharedState.with { |r| r.del(instance.cache_key) } if without_cache

        instance.execute
      end

      def initialize(task)
        @task = task.to_sym
      end

      def execute
        raise ArgumentError, "Unknown task: #{task.inspect}" unless TASKS.include?(task)
        raise NotImplementedError unless respond_to?(task, true)

        send(task) # rubocop:disable GitlabSecurity/PublicSend -- We control the list of tasks in the source code
      end

      def cache_key
        [self.class.name.underscore, :execute_every, task].flatten.join(':')
      end

      private

      def execute_every(period)
        # We don't want any delay interval in development environments,
        # so lets disable the cache unless we are in production.
        return yield if Rails.env.development?

        Gitlab::Redis::SharedState.with do |redis|
          key_set = redis.set(cache_key, 1, ex: period, nx: true)
          break false unless key_set

          yield
        end
      end

      def logger
        @logger ||= ::Search::Zoekt::Logger.build
      end

      def info(task, **payload)
        logger.info(build_structured_payload(**payload.merge(task: task)))
      end

      # An initial implementation of eviction logic. For now, it's a .com-only task
      def eviction
        return false unless ::Gitlab::Saas.feature_available?(:exact_code_search)
        return false if Feature.disabled?(:zoekt_reallocation_task, Feature.current_request)

        execute_every 5.minutes do
          nodes = ::Search::Zoekt::Node.online.find_each.to_a
          over_watermark_nodes = nodes.select(&:watermark_exceeded_high?)

          break if over_watermark_nodes.empty?

          info(:eviction, message: 'Detected nodes over watermark',
            watermark_limit_high: ::Search::Zoekt::Node::WATERMARK_LIMIT_HIGH,
            count: over_watermark_nodes.count)

          over_watermark_nodes.each do |node|
            sizes = {}

            node.indices.each_batch do |batch|
              scope = Namespace.includes(:root_storage_statistics) # rubocop:disable CodeReuse/ActiveRecord -- this is a temporary incident mitigation task
                               .by_parent(nil)
                               .id_in(batch.select(:namespace_id))

              scope.each do |group|
                sizes[group.id] = group.root_storage_statistics&.repository_size || 0
              end
            end

            sorted = sizes.to_a.sort_by { |_k, v| v }

            namespaces_to_move = []
            total_repository_size = 0
            node_original_used_bytes = node.used_bytes
            sorted.each do |namespace_id, repository_size|
              node.used_bytes -= repository_size
              namespaces_to_move << namespace_id
              total_repository_size += repository_size

              break unless node.watermark_exceeded_low?
            end

            unassign_namespaces_from_node(node, namespaces_to_move, node_original_used_bytes, total_repository_size)
          end
        end
      end

      def unassign_namespaces_from_node(node, namespaces_to_move, node_original_used_bytes, total_repository_size)
        return if namespaces_to_move.empty?

        info(:eviction, message: 'Unassigning namespaces from node',
          watermark_limit_high: ::Search::Zoekt::Node::WATERMARK_LIMIT_HIGH,
          count: namespaces_to_move.count,
          node_used_bytes: node_original_used_bytes,
          node_expected_used_bytes: node.used_bytes,
          total_repository_size: total_repository_size,
          meta: node.metadata_json
        )

        namespaces_to_move.each_slice(100) do |namespace_ids|
          ::Search::Zoekt::EnabledNamespace.for_root_namespace_id(namespace_ids).update_last_used_storage_bytes!

          ::Search::Zoekt::Replica.for_namespace(namespace_ids).each_batch do |batch|
            batch.delete_all
          end
        end
      end

      # A temporary task to simplify the .com Zoekt rollout
      # rubocop:disable CodeReuse/ActiveRecord -- this is a temporary task, which will be removed after the rollout
      def dot_com_rollout
        return false unless ::Gitlab::Saas.feature_available?(:exact_code_search)
        return false if Feature.disabled?(:zoekt_dot_com_rollout, Feature.current_request)

        execute_every 2.hours do
          indexed_namespaces_ids = Search::Zoekt::EnabledNamespace.find_each.map(&:root_namespace_id).to_set

          sizes = {}
          GitlabSubscription.with_a_paid_hosted_plan.not_expired.each_batch(of: 100) do |batch|
            namespace_ids = batch.pluck(:namespace_id) # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- each_batch limits the query
            filtered_namespace_ids = namespace_ids.reject { |id| indexed_namespaces_ids.include?(id) }

            scope = Group.includes(:root_storage_statistics).top_level.id_in(filtered_namespace_ids)

            scope.find_each do |n|
              sizes[n.id] = n.root_storage_statistics.repository_size if n.root_storage_statistics
            end
          end

          sorted = sizes.to_a.sort_by { |_k, v| v }

          count = 0
          size = 0

          sorted.take(DOT_COM_ROLLOUT_LIMIT).each do |id, s|
            size += s
            break count if size > DOT_COM_ROLLOUT_TARGET_BYTES

            Search::Zoekt::EnabledNamespace.create!(root_namespace_id: id, search: true)
            count += 1
          end

          logger.info(build_structured_payload(
            task: :dot_com_rollout,
            message: 'Rollout has been completed',
            namespace_count: count
          ))

          count
        end
      end
      # rubocop:enable CodeReuse/ActiveRecord

      def remove_expired_subscriptions
        return false unless ::Gitlab::Saas.feature_available?(:exact_code_search)

        execute_every 10.minutes do
          Search::Zoekt::EnabledNamespace.destroy_namespaces_with_expired_subscriptions!
        end
      end

      # rubocop: disable Metrics/AbcSize -- After removal of FFs metrics will be fine
      def node_assignment
        return false if Feature.disabled?(:zoekt_node_assignment, Feature.current_request)

        execute_every 1.hour do
          nodes = ::Search::Zoekt::Node.online.find_each.to_a

          break false if nodes.empty?

          zoekt_indices = []

          EnabledNamespace.with_missing_indices.preload_storage_statistics.find_each do |zoekt_enabled_namespace|
            storage_statistics = zoekt_enabled_namespace.namespace.root_storage_statistics
            unless storage_statistics
              logger.error(build_structured_payload(
                task: :node_assignment,
                message: "RootStorageStatistics isn't available",
                zoekt_enabled_namespace_id: zoekt_enabled_namespace.id
              ))

              next
            end

            space_required = BUFFER_FACTOR * storage_statistics.repository_size

            node = nodes.max_by { |n| n.total_bytes - n.used_bytes }

            if (node.used_bytes + space_required) <= node.total_bytes * ::Search::Zoekt::Node::WATERMARK_LIMIT_LOW
              zoekt_index = Search::Zoekt::Index.new(
                namespace_id: zoekt_enabled_namespace.root_namespace_id,
                zoekt_node_id: node.id,
                zoekt_enabled_namespace: zoekt_enabled_namespace,
                replica: Replica.for_enabled_namespace!(zoekt_enabled_namespace),
                reserved_storage_bytes: space_required
              )
              zoekt_index.state = :ready if space_required == 0
              zoekt_indices << zoekt_index
              node.used_bytes += space_required
            elsif Feature.enabled?(:zoekt_create_multiple_indices, zoekt_enabled_namespace.namespace)
              multiple_indices = NamespaceAssignmentService.new(zoekt_enabled_namespace).execute
              if multiple_indices.empty?
                logger.error(build_structured_payload(
                  task: :node_assignment,
                  message: 'Namespace is too big even for multiple indices',
                  zoekt_enabled_namespace_id: zoekt_enabled_namespace.id
                ))
              else
                zoekt_indices.concat(multiple_indices)
              end
            else
              logger.error(build_structured_payload(
                task: :node_assignment,
                message: 'Space is not available in Node', zoekt_enabled_namespace_id: zoekt_enabled_namespace.id,
                meta: node.metadata_json
              ))
            end
          end

          zoekt_indices.each do |zoekt_index|
            unless zoekt_index.save
              logger.error(build_structured_payload(task: :node_assignment,
                message: 'Could not save Search::Zoekt::Index', zoekt_index: zoekt_index.attributes.compact))
            end
          end
        end
      end
      # rubocop: enable Metrics/AbcSize

      def node_with_negative_unclaimed_storage_bytes_check
        execute_every 1.hour do
          Search::Zoekt::Node.negative_unclaimed_storage_bytes.each_batch do |batch|
            Gitlab::EventStore.publish(
              Search::Zoekt::NodeWithNegativeUnclaimedStorageEvent.new(data: { node_ids: batch.pluck_primary_key })
            )
          end
        end
      end

      # indices that don't have zoekt_repositories are already in `ready` state
      def mark_indices_as_ready
        execute_every 10.minutes do
          initializing_indices = Search::Zoekt::Index.initializing
          if initializing_indices.empty?
            logger.info(build_structured_payload(task: :mark_indices_as_ready, message: 'Set indices ready', count: 0))
            break
          end

          count = 0
          initializing_indices.each_batch do |batch|
            records = batch.with_all_finished_repositories
            next if records.empty?

            count += records.update_all(state: :ready)
          end
          logger.info(build_structured_payload(task: :mark_indices_as_ready, message: 'Set indices ready',
            count: count))
        end
      end

      def initial_indexing
        ::Search::Zoekt::Index.pending.ordered.limit(INITIAL_INDEXING_LIMIT).each do |index|
          Gitlab::EventStore.publish(InitialIndexingEvent.new(data: { index_id: index.id }))
        end
      end

      # This task does not need to run on .com
      def auto_index_self_managed
        return if Gitlab::Saas.feature_available?(:exact_code_search)
        return unless Gitlab::CurrentSettings.zoekt_auto_index_root_namespace?

        execute_every 10.minutes do
          Namespace.group_namespaces.root_namespaces_without_zoekt_enabled_namespace.each_batch do |batch|
            data = batch.pluck_primary_key.map { |id| { root_namespace_id: id } }
            Search::Zoekt::EnabledNamespace.insert_all(data)
          end
        end
      end

      def update_replica_states
        return false if Feature.disabled?(:zoekt_replica_state_updates, Feature.current_request)

        execute_every 2.minutes do
          ReplicaStateService.execute
        end
      end

      def update_index_used_bytes
        execute_every 5.minutes do
          Search::Zoekt::Index.update_used_storage_bytes!
        end
      end

      def index_should_be_marked_as_orphaned_check
        execute_every 10.minutes do
          unless Index.should_be_marked_as_orphaned.exists?
            logger.info(build_structured_payload(task: task, message: 'Nothing to mark as orphaned'))
            break
          end

          Gitlab::EventStore.publish(OrphanedIndexEvent.new(data: {}))
        end
      end

      def index_to_delete_check
        execute_every 10.minutes do
          next unless Search::Zoekt::Index.should_be_deleted.exists?

          Gitlab::EventStore.publish(
            Search::Zoekt::IndexMarkedAsToDeleteEvent.new(data: {})
          )
        end
      end

      def repo_should_be_marked_as_orphaned_check
        execute_every 10.minutes do
          next unless Search::Zoekt::Repository.should_be_marked_as_orphaned.exists?

          Gitlab::EventStore.publish(
            Search::Zoekt::OrphanedRepoEvent.new(data: {})
          )
        end
      end

      def repo_to_delete_check
        execute_every 10.minutes do
          Search::Zoekt::Repository.should_be_deleted.each_batch do |batch|
            Gitlab::EventStore.publish(
              Search::Zoekt::RepoMarkedAsToDeleteEvent.new(
                data: { zoekt_repo_ids: batch.pluck_primary_key }
              )
            )
          end
        end
      end

      def repo_to_index_check
        execute_every 10.minutes do
          Search::Zoekt::Repository.pending_or_initializing.each_batch do |batch|
            Gitlab::EventStore.publish(
              Search::Zoekt::RepoToIndexEvent.new(data: { zoekt_repo_ids: batch.pluck_primary_key })
            )
          end
        end
      end

      def indices_to_evict_check
        Search::Zoekt::Index.critical_watermark_exceeded.each_batch do |batch|
          Gitlab::EventStore.publish(
            Search::Zoekt::IndexToEvictEvent.new(data: { index_ids: batch.pluck_primary_key })
          )
        end
      end

      def index_mismatched_watermark_check
        execute_every 10.minutes do
          Search::Zoekt::Index.each_batch do |batch|
            ids = batch.with_mismatched_watermark_levels.or(batch.negative_reserved_storage_bytes).pluck_primary_key
            next if ids.empty?

            Gitlab::EventStore.publish(
              Search::Zoekt::IndexWatermarkChangedEvent.new(
                data: {
                  index_ids: ids,
                  watermark_level: "mismatched"
                }
              )
            )
          end
        end
      end

      def lost_nodes_check
        return false if Rails.env.development?
        return false unless Node.marking_lost_enabled?

        lost_node = Node.lost.limit(1).select(:id).last
        return false unless lost_node

        execute_every 10.minutes do
          Gitlab::EventStore.publish(LostNodeEvent.new(data: { zoekt_node_id: lost_node.id }))
        end
      end

      def adjust_indices_reserved_storage_bytes
        execute_every 10.minutes do
          Index.should_be_reserved_storage_bytes_adjusted.each_batch do |batch|
            Gitlab::EventStore.publish(
              AdjustIndicesReservedStorageBytesEvent.new(data: { index_ids: batch.pluck_primary_key })
            )
          end
        end
      end
    end
  end
end
