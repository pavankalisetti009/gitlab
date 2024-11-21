# frozen_string_literal: true

module Geo
  class MetricsUpdateWorker
    include ApplicationWorker

    idempotent!
    worker_has_external_dependencies!
    data_consistency :sticky
    deduplicate :until_executed, ttl: 1.hour

    include Gitlab::Geo::LogHelpers
    # rubocop:disable Scalability/CronWorkerContext
    # This worker does not perform work scoped to a context
    include CronjobQueue
    # rubocop:enable Scalability/CronWorkerContext

    feature_category :geo_replication

    def perform
      return unless Feature.enabled?(:geo_metrics_update_worker, type: :ops) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- Metrics collection is instance wide

      Geo::MetricsUpdateService.new.execute
    end
  end
end
