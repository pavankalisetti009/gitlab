# frozen_string_literal: true

module Geo
  # Worker that marks registries as pending to verify in batches
  # to be verified by Geo periodic workers
  #
  # no-op - to be removed
  class BulkMarkVerificationPendingBatchWorker
    include ApplicationWorker

    data_consistency :always

    include GeoQueue
    include LimitedCapacity::Worker
    include ::Gitlab::Geo::LogHelpers

    # Maximum number of jobs allowed to run concurrently
    MAX_RUNNING_JOBS = 1

    idempotent!
    loggable_arguments 0

    class << self
      def perform_with_capacity(...); end
    end

    def perform_work(...); end

    def remaining_work_count(...)
      0
    end

    def max_running_jobs
      MAX_RUNNING_JOBS
    end
  end
end
