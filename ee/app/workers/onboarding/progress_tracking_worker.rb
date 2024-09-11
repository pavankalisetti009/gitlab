# frozen_string_literal: true

module Onboarding
  class ProgressTrackingWorker
    include ApplicationWorker

    data_consistency :always # rubocop:disable SidekiqLoadBalancing/WorkerDataConsistency -- does writes and requires consistency

    sidekiq_options retry: 3

    feature_category :onboarding
    worker_resource_boundary :cpu
    urgency :low

    deduplicate :until_executed
    idempotent!

    def perform(namespace_id, action)
      namespace = Namespace.find_by_id(namespace_id)
      return unless namespace && action

      Onboarding::ProgressService.new(namespace).execute(action: action.to_sym)
    end
  end
end
