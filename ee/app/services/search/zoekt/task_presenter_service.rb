# frozen_string_literal: true

module Search
  module Zoekt
    class TaskPresenterService
      DEFAULT_LIMIT = 20
      MAX_LIMIT = 200

      attr_reader :node, :concurrency_limit

      def self.execute(...)
        new(...).execute
      end

      def initialize(node)
        @node = node
        @concurrency_limit = if Feature.enabled?(:zoekt_new_concurrency_limit_logic, Feature.current_request)
                               get_concurrency_limit(node: node)
                             else
                               get_legacy_concurrency_limit(node: node)
                             end
      end

      def execute
        [].tap do |payload|
          break [] if ::Gitlab::CurrentSettings.zoekt_indexing_paused?

          node.tasks.each_task_for_processing(limit: concurrency_limit) do |task|
            payload << TaskSerializerService.execute(task)
          end
        end
      end

      private

      def get_concurrency_limit(node:)
        # concurrency override is going to become a setting https://gitlab.com/gitlab-org/gitlab/-/issues/478595
        concurrency = node.metadata['concurrency_override'] || node.metadata['concurrency']

        return DEFAULT_LIMIT if concurrency.to_i == 0

        concurrency.clamp(0, MAX_LIMIT)
      end

      def get_legacy_concurrency_limit(node:)
        task_count = node.metadata['task_count']
        # concurrency override is going to become a setting https://gitlab.com/gitlab-org/gitlab/-/issues/478595
        concurrency = node.metadata['concurrency_override'] || node.metadata['concurrency']

        return DEFAULT_LIMIT if task_count.nil? || concurrency.nil? || concurrency == 0

        (concurrency - task_count).clamp(0, MAX_LIMIT)
      end
    end
  end
end
