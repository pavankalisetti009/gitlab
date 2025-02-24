# frozen_string_literal: true

module Search
  module Zoekt
    class RolloutWorker
      include ApplicationWorker
      include Search::Worker
      include CronjobQueue # rubocop:disable Scalability/CronWorkerContext -- there is no relevant metadata
      include Gitlab::ExclusiveLeaseHelpers
      prepend ::Geo::SkipSecondary

      deduplicate :until_executed
      data_consistency :sticky
      idempotent!
      urgency :low

      defer_on_database_health_signal :gitlab_main,
        [:zoekt_nodes, :zoekt_enabled_namespaces, :zoekt_replicas, :zoekt_indices, :zoekt_repositories, :zoekt_tasks],
        10.minutes

      MAX_RETRIES = 5
      INITIAL_BACKOFF = 5.minutes

      def perform(retry_count = 0)
        return false if Gitlab::CurrentSettings.zoekt_indexing_paused?
        return false unless Search::Zoekt.licensed_and_indexing_enabled?
        return false unless Feature.enabled?(:zoekt_rollout_worker, Feature.current_request)

        in_lock(self.class.name.underscore, ttl: 10.minutes, retries: 10, sleep_sec: 1) do
          result = ::Search::Zoekt::RolloutService.execute(dry_run: false)

          if result.success?
            log_info message: "RolloutWorker succeeded: #{result.message}"
            self.class.perform_async # Immediately schedule another job
          else
            log_info message: "RolloutWorker did not do any work: #{result.message}"

            if retry_count < MAX_RETRIES
              backoff_time = INITIAL_BACKOFF * (2**retry_count)

              self.class.perform_at(backoff_time.from_now, retry_count + 1)
            else
              log_info message: "RolloutWorker exceeded max back off interval. Last message: #{result.message}"
            end
          end
        end
      end

      private

      def logger
        @logger ||= ::Search::Zoekt::Logger.build
      end

      def log_info(**payload)
        logger.info(build_structured_payload(**payload))
      end
    end
  end
end
