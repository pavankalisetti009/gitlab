# frozen_string_literal: true

module SecretsManagement
  class SecretRotationReminderBatchWorker
    include ApplicationWorker

    data_consistency :sticky

    include CronjobQueue # rubocop: disable Scalability/CronWorkerContext -- this is a cronjob.

    feature_category :secrets_management

    idempotent!

    MAX_RUNTIME = 30.seconds

    def perform
      runtime_limiter = Gitlab::Metrics::RuntimeLimiter.new(MAX_RUNTIME)
      service = SecretsManagement::SecretRotationBatchReminderService.new

      processed_total = 0
      skipped_total = 0

      loop do
        result = service.execute

        processed_total += result[:processed_count]
        skipped_total += result[:skipped_count]

        # Exit if no more work to do
        break if result[:processed_count] < SecretsManagement::SecretRotationBatchReminderService::BATCH_SIZE

        # Exit if we've exceeded runtime limit
        break if runtime_limiter.over_time?
      end

      # Log metrics for monitoring
      log_extra_metadata_on_done(:result, {
        status: runtime_limiter.over_time? ? :limit_reached : :completed,
        processed_secrets: processed_total,
        skipped_secrets: skipped_total
      })
    end
  end
end
