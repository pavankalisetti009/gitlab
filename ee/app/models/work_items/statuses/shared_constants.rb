# frozen_string_literal: true

module WorkItems
  module Statuses
    module SharedConstants
      CATEGORIES = {
        triage: 1,
        to_do: 2,
        in_progress: 3,
        done: 4,
        cancelled: 5
      }.freeze

      CATEGORY_ICONS = {
        triage: 'status-neutral',
        to_do: 'status-waiting',
        in_progress: 'status-running',
        done: 'status-success',
        cancelled: 'status-cancelled'
      }.freeze

      DEFAULT_STATUS_CATEGORIES = {
        default_open_status: [:triage, :to_do, :in_progress],
        default_closed_status: [:done, :cancelled],
        default_duplicate_status: [:done, :cancelled]
      }.freeze
    end
  end
end
