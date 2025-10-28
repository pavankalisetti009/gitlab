# frozen_string_literal: true

module SecretsManagement
  module SecretStatus
    extend ActiveSupport::Concern

    STALE_THRESHOLD = 30.seconds

    STATUSES = {
      completed: 'COMPLETED',
      create_stale: 'CREATE_STALE',
      update_stale: 'UPDATE_STALE',
      create_in_progress: 'CREATE_IN_PROGRESS',
      update_in_progress: 'UPDATE_IN_PROGRESS'
    }.freeze

    def status
      update_status || create_status || STATUSES[:completed]
    end

    def valid_for_update?
      return false unless valid?

      if status == STATUSES[:create_in_progress]
        errors.add(:base, 'Secret create in progress.')
      elsif status == STATUSES[:create_stale]
        errors.add(:base, 'Secret creation did not complete and is now stale.')
      elsif status == STATUSES[:update_stale]
        errors.add(:base, 'Secret update did not complete and is now stale.')
      elsif status == STATUSES[:update_in_progress]
        errors.add(:base, 'Secret update in progress.')
      end

      errors.empty?
    end

    private

    def update_status
      return unless update_started_at || update_completed_at

      return STATUSES[:completed] if update_completed_at.present?

      return STATUSES[:update_in_progress] if recent?(update_started_at)

      STATUSES[:update_stale]
    end

    def create_status
      return STATUSES[:create_in_progress] if create_started_at.nil? && create_completed_at.nil?

      if create_started_at && create_completed_at.nil?
        return recent?(create_started_at) ? STATUSES[:create_in_progress] : STATUSES[:create_stale]
      end

      STATUSES[:completed]
    end

    def recent?(time)
      time && time > STALE_THRESHOLD.ago
    end
  end
end
