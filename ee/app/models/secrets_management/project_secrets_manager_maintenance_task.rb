# frozen_string_literal: true

module SecretsManagement
  class ProjectSecretsManagerMaintenanceTask < ApplicationRecord
    self.table_name = 'project_secrets_manager_maintenance_tasks'

    enum :action, {
      provision: 0,
      deprovision: 1
    }

    belongs_to :user
    belongs_to :project_secrets_manager,
      class_name: 'SecretsManagement::ProjectSecretsManager'

    validates :action,
      presence: true,
      uniqueness: { scope: :project_secrets_manager_id }

    validates :user_id, presence: true
    validates :project_secrets_manager_id, presence: true
    validates :retry_count,
      numericality: {
        greater_than_or_equal_to: 0,
        only_integer: true
      }

    # Find tasks stale in processing for more than the threshold
    scope :stale, ->(threshold) {
      where(last_processed_at: ...threshold.ago)
    }

    # Find tasks that can still be retried
    scope :retryable, ->(max_retries) {
      where(retry_count: ...max_retries)
    }
  end
end
