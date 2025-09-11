# frozen_string_literal: true

module WorkItems
  module Statuses
    # Not an ancestor class but a module because system-defined lifecycle isn't a model.
    # Using a shared module allows us to use it as an interface for GraphQL GlobalID input validation.
    # We're not using `BaseLifecycle` here because it's not a class.
    module Lifecycle
      def default_status_for_work_item(work_item)
        if work_item.open?
          default_open_status
        elsif work_item.duplicated?
          default_duplicate_status
        elsif work_item.closed?
          default_closed_status
        end
      end

      def status_counts
        ordered_statuses.map do |status|
          # Logic will be implemented with https://gitlab.com/gitlab-org/gitlab/-/issues/554090
          { status: status, count: nil }
        end
      end
    end
  end
end
