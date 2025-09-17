# frozen_string_literal: true

module VirtualRegistries
  module Cleanup
    class Policy < ApplicationRecord
      belongs_to :group

      enum :status, { scheduled: 0, running: 1, failed: 2 }

      validates :group, top_level_group: true, presence: true, uniqueness: true
      validates :keep_n_days_after_download, presence: true,
        numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 365 }
      validates :cadence, inclusion: { in: [1, 7, 14, 30, 90] }
      validates :last_run_detailed_metrics, json_schema:
        { filename: 'virtual_registry_cleanup_detailed_metrics', detail_errors: true, size_limit: 64.kilobytes },
        allow_blank: true
      validates :last_run_deleted_size, :last_run_deleted_entries_count,
        numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validates :enabled, :notify_on_success, :notify_on_failure, inclusion: { in: [true, false] }
      validates :failure_message, length: { maximum: 255 }, allow_nil: true
    end
  end
end
