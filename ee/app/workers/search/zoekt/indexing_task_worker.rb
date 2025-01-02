# frozen_string_literal: true

module Search
  module Zoekt
    class IndexingTaskWorker
      include ApplicationWorker
      include Search::Worker
      prepend ::Geo::SkipSecondary

      data_consistency :delayed
      idempotent!
      urgency :low

      concurrency_limit -> {
        2_000 if Feature.enabled?(:zoekt_increased_concurrency_indexing_task_worker, Feature.current_request)
      }

      def perform(project_id, task_type, options = {})
        return false unless ::Search::Zoekt.licensed_and_indexing_enabled?

        options = options.with_indifferent_access
        keyword_args = {
          node_id: options[:node_id], force: options[:force], delay: options[:delay],
          root_namespace_id: options[:root_namespace_id]
        }.compact
        IndexingTaskService.execute(project_id, task_type, **keyword_args)
      end
    end
  end
end
