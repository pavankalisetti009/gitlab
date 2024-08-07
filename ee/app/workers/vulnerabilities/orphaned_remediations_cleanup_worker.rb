# frozen_string_literal: true

module Vulnerabilities
  class OrphanedRemediationsCleanupWorker
    include ApplicationWorker
    # This worker does not perform work scoped to a context
    include CronjobQueue # rubocop:disable Scalability/CronWorkerContext

    deduplicate :until_executing, including_scheduled: true
    idempotent!
    data_consistency :always # rubocop:disable SidekiqLoadBalancing/WorkerDataConsistency

    feature_category :vulnerability_management

    # default is 1000. Saving to constant for spec use
    BATCH_SIZE = 1000

    def perform(*_args)
      # rubocop:disable CodeReuse/ActiveRecord
      Vulnerabilities::Remediation.where.missing(:finding_remediations).each_batch(of: BATCH_SIZE) do |batch|
        batch.delete_all
      end
      # rubocop:enable CodeReuse/ActiveRecord
    end
  end
end
