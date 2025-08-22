# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    module PolicySyncState
      POLICY_SYNC_TTL = 24.hours.to_i
      POLICY_SYNC_CONTEXT_KEY = :policy_sync_config_id

      class State
        include Gitlab::Utils::StrongMemoize

        def self.from_application_context
          config_id = Gitlab::ApplicationContext.current_context_attribute(POLICY_SYNC_CONTEXT_KEY)&.to_i || return

          new(config_id)
        end

        attr_reader :config_id

        def initialize(config_id)
          @config_id = config_id
        end

        # Appends project IDs, adding to the pending set and incrementing the total counter
        def append_projects(project_ids)
          return if feature_disabled? || project_ids.empty?

          with_redis do |redis|
            redis.multi do |multi|
              multi.sadd(projects_sync_key, project_ids)
              multi.incrby(total_projects_key, project_ids.size)

              multi.expire(projects_sync_key, POLICY_SYNC_TTL)
              multi.expire(total_projects_key, POLICY_SYNC_TTL)
            end
          end
        end

        # Marks the project ID as successfully synced and triggers a status update
        def finish_project(project_id)
          return if feature_disabled?

          with_redis do |redis|
            redis.srem(projects_sync_key, project_id.to_s)
          end

          trigger_subscription
        end

        # Marks the project ID as failed to sync and triggers a status update
        def fail_project(project_id)
          return if feature_disabled?

          with_redis do |redis|
            redis.multi do |multi|
              multi.sadd(failed_projects_sync_key, project_id)
              multi.srem(projects_sync_key, project_id.to_s)

              multi.expire(failed_projects_sync_key, POLICY_SYNC_TTL)
            end
          end

          trigger_subscription
        end

        # Registers an MR for tracking and initializes the worker counter
        def start_merge_request(merge_request_id)
          return if feature_disabled?

          with_redis do |redis|
            redis.multi do |multi|
              multi.sadd(merge_requests_sync_key, merge_request_id)
              multi.incr(total_merge_requests_key)
              multi.set(merge_request_workers_sync_key(merge_request_id), 0)

              multi.expire(merge_requests_sync_key, POLICY_SYNC_TTL)
              multi.expire(total_merge_requests_key, POLICY_SYNC_TTL)
              multi.expire(merge_request_workers_sync_key(merge_request_id), POLICY_SYNC_TTL)
            end
          end
        end

        # Increments the worker counter for a given merge request
        def start_merge_request_worker(merge_request_id)
          return if feature_disabled?

          with_redis do |redis|
            redis.incr(merge_request_workers_sync_key(merge_request_id))
          end
        end

        # Decrements the merge request worker count and if it hits zero, marks the merge request
        # as fully synced
        def finish_merge_request_worker(merge_request_id)
          return if feature_disabled?

          with_redis do |redis|
            new_value = redis.decr(merge_request_workers_sync_key(merge_request_id))

            if new_value <= 0
              redis.srem(merge_requests_sync_key, merge_request_id.to_s)

              trigger_subscription
            end
          end
        end

        def sync_in_progress?
          return false if feature_disabled?

          with_redis do |redis|
            conditions = redis.multi do |multi|
              # rubocop:disable CodeReuse/ActiveRecord -- false positive
              multi.exists?(total_projects_key)
              multi.exists?(total_merge_requests_key)
              # rubocop:enable CodeReuse/ActiveRecord

              multi.scard(projects_sync_key)
              multi.scard(merge_requests_sync_key)
            end

            # rubocop:disable Layout/LineLength -- TODO
            conditions.then do |total_projects, total_merge_requests, project_pending_count, merge_request_pending_count|
              total_projects && total_merge_requests && (project_pending_count > 0 || merge_request_pending_count > 0)
            end
            # rubocop:enable Layout/LineLength
          end
        end

        def clear
          return if feature_disabled?

          with_redis do |redis|
            redis.del(projects_sync_key)
            redis.del(total_projects_key)
            redis.del(failed_projects_sync_key)
            redis.del(merge_requests_sync_key)
            redis.del(total_merge_requests_key)
          end
        end

        # Pending project IDs.
        def pending_projects
          get_items(projects_sync_key)
        end

        # Failed project IDs.
        def failed_projects
          get_items(failed_projects_sync_key)
        end

        # Pending merge request IDs.
        def pending_merge_requests
          get_items(merge_requests_sync_key)
        end

        # Total number of pending merge requests
        def total_merge_request_workers_count(merge_request_id)
          with_redis do |redis|
            redis.get(merge_request_workers_sync_key(merge_request_id))&.to_i
          end
        end

        # Total number of pending projects
        def total_project_count
          with_redis do |redis|
            redis.get(total_projects_key)&.to_i
          end
        end

        # Total number of pending merge requests
        def total_merge_request_count
          with_redis do |redis|
            redis.get(total_merge_requests_key)&.to_i
          end
        end

        private

        def redis_key_tag
          "{security_policy_sync:#{config_id}}"
        end

        # Set: project IDs pending synchronization
        def projects_sync_key
          "#{redis_key_tag}:projects"
        end

        # Integer: initial total number of projects for percentage calculation
        def total_projects_key
          "#{redis_key_tag}:total_projects"
        end

        # Set: merge request IDs with at least one active sync worker
        def merge_requests_sync_key
          "#{redis_key_tag}:merge_requests"
        end

        # Integer: Countdown for active downstream workers for a merge request
        def merge_request_workers_sync_key(merge_request_id)
          "#{redis_key_tag}:merge_requests:#{merge_request_id}:workers"
        end

        # Integer: Total number of unique merge requests processed during sync
        def total_merge_requests_key
          "#{redis_key_tag}:total_merge_requests"
        end

        # Set: Project IDs that failed to sync after all retries
        def failed_projects_sync_key
          "#{redis_key_tag}:failed_projects"
        end

        def get_progress(pending, total)
          return if total == 0

          ((total - pending).to_f / total * 100).round
        end

        def trigger_subscription
          projects_pending, projects_total, all_failed_projects, merge_requests_pending, merge_requests_total =
            with_redis do |redis|
              [
                redis.scard(projects_sync_key),
                redis.get(total_projects_key).to_i,
                redis.smembers(failed_projects_sync_key),
                redis.scard(merge_requests_sync_key),
                redis.get(total_merge_requests_key).to_i
              ]
            end

          GraphqlTriggers.security_policies_sync_updated(
            policy_configuration,
            get_progress(projects_pending, projects_total),
            projects_total,
            all_failed_projects,
            get_progress(merge_requests_pending, merge_requests_total),
            merge_requests_total
          )
        end

        def feature_disabled?
          strong_memoize_with(:feature_disabled, config_id) do
            project = policy_configuration&.security_policy_management_project

            break true unless project

            Feature.disabled?(:security_policy_sync_propagation_tracking, project)
          end
        end

        def policy_configuration
          strong_memoize_with(:policy_configuration, config_id) do
            Security::OrchestrationPolicyConfiguration.find_by_id(config_id)
          end
        end

        def get_items(key)
          with_redis do |redis|
            redis.smembers(key)
          end
        end

        def with_redis(&block)
          Gitlab::Redis::SharedState.with(&block) # rubocop:disable CodeReuse/ActiveRecord -- false positive
        end
      end

      module Callbacks
        def clear_policy_sync_state(config_id)
          State.new(config_id).clear
        end

        def append_projects_to_sync(config_id, project_ids)
          State.new(config_id).append_projects(project_ids)
        end

        def finish_project_policy_sync(project_id)
          State.from_application_context&.finish_project(project_id)
        end

        def fail_project_policy_sync(project_id)
          State.from_application_context&.fail_project(project_id)
        end

        def start_merge_request_policy_sync(merge_request_id)
          State.from_application_context&.start_merge_request(merge_request_id)
        end

        def start_merge_request_worker_policy_sync(merge_request_id)
          State.from_application_context&.start_merge_request_worker(merge_request_id)
        end

        def finish_merge_request_worker_policy_sync(merge_request_id)
          State.from_application_context&.finish_merge_request_worker(merge_request_id)
        end
      end
    end
  end
end
