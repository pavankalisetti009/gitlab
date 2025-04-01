# frozen_string_literal: true

module WorkItems
  module Statuses
    # Not an ancestor class but a module because system-defined status isn't a model.
    # Using a shared module allows us to use it for GraphQL GlobalID input validation.
    # We're not using `BaseStatus` here because it's not a class.
    module Status
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
    end
  end
end
