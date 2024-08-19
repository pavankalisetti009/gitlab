# frozen_string_literal: true

module WorkItems
  module RolledupDates
    class UpdateRolledupDatesWorker
      include ApplicationWorker
      # rubocop: disable SidekiqLoadBalancing/WorkerDataConsistency -- this worker updates a nested tree of data
      data_consistency :always
      # rubocop: enable SidekiqLoadBalancing/WorkerDataConsistency
      feature_category :portfolio_management
      idempotent!

      def perform(id)
        ::WorkItems::Widgets::RolledupDatesService::HierarchiesUpdateService
          .new(::WorkItem.id_in(id))
          .execute
      end
    end
  end
end
