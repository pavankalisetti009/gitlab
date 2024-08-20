# frozen_string_literal: true

module Search
  module Zoekt
    class SchedulingWorker
      include ApplicationWorker
      include CronjobQueue
      prepend ::Geo::SkipSecondary

      data_consistency :always # rubocop:disable SidekiqLoadBalancing/WorkerDataConsistency -- It is a Cronjob
      feature_category :global_search
      idempotent!
      urgency :low

      def perform(task = nil)
        return false if Feature.disabled?(:zoekt_scheduling_worker, type: :beta)

        return initiate if task.nil?

        SchedulingService.execute(task)
      end

      private

      def initiate
        SchedulingService::TASKS.each do |task|
          with_context(related_class: self.class) { self.class.perform_async(task) }
        end
      end
    end
  end
end
