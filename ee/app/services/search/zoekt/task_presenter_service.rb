# frozen_string_literal: true

module Search
  module Zoekt
    class TaskPresenterService
      attr_reader :node, :concurrency_limit

      def self.execute(...)
        new(...).execute
      end

      def initialize(node)
        @node = node
        @concurrency_limit = node.concurrency_limit
      end

      def execute
        [].tap do |payload|
          break [] if ::Gitlab::CurrentSettings.zoekt_indexing_paused?

          node.tasks.each_task_for_processing(limit: concurrency_limit) do |task|
            payload << TaskSerializerService.execute(task)
          end
        end
      end
    end
  end
end
