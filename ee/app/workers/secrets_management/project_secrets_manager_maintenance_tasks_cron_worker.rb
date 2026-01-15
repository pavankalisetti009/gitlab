# frozen_string_literal: true

module SecretsManagement
  class ProjectSecretsManagerMaintenanceTasksCronWorker
    include ApplicationWorker
    include CronjobQueue # rubocop: disable Scalability/CronWorkerContext -- this is a cronjob.
    include EachBatch

    data_consistency :sticky
    idempotent!
    feature_category :secrets_management

    BATCH_SIZE = 100
    STALE_THRESHOLD = 5.minutes
    MAX_RETRIES = 3

    def perform
      retry_failed_tasks
    end

    private

    def retry_failed_tasks
      SecretsManagement::ProjectSecretsManagerMaintenanceTask
        .stale(STALE_THRESHOLD)
        .retryable(MAX_RETRIES)
        .limit(BATCH_SIZE)
        .each_batch do |batch|
          batch.each do |task|
            Gitlab::AppLogger.warn(
              message: "Retrying failed secrets_manager maintenance task",
              task_id: task.id,
              retry_count: task.retry_count,
              stale_duration: Time.current - task.last_processed_at
            )

            task.update!(
              last_processed_at: Time.current,
              retry_count: task.retry_count + 1
            )

            SecretsManagement::DeprovisionProjectSecretsManagerWorker.perform_async(
              task.user_id,
              task.project_secrets_manager_id
            )
          end
        end
    end
  end
end
