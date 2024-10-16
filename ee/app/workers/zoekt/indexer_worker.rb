# frozen_string_literal: true

# This is deprecated and soon will be removed. We use Task to index
module Zoekt
  class IndexerWorker
    MAX_JOBS_PER_HOUR = 3600
    TIMEOUT = 2.hours
    RETRY_IN_IF_LOCKED = 10.minutes
    RETRY_IN_PERIOD_IF_TOO_MANY_REQUESTS = 5.minutes

    REINDEXING_CHANCE_PERCENTAGE = 0.5

    include ApplicationWorker
    include Search::Worker
    prepend ::Geo::SkipSecondary

    data_consistency :always # rubocop:disable SidekiqLoadBalancing/WorkerDataConsistency -- This worker updates data
    include Gitlab::ExclusiveLeaseHelpers

    urgency :throttled
    sidekiq_options retry: 2
    idempotent!
    pause_control :zoekt
    concurrency_limit -> { 30 if Feature.enabled?(:zoekt_limit_indexing_concurrency) }

    def perform(project_id, options = {}); end
  end
end
