# frozen_string_literal: true

module Search
  module Elastic
    class ReindexingService
      # skip projects, all namespace and project data is handled by `namespaces` task
      OPTIONS = { 'skip' => 'projects' }.freeze

      attr_reader :delay

      def self.execute(...)
        new(...).execute
      end

      def initialize(delay: 0)
        @delay = delay
      end

      def execute
        initial_task = Search::Elastic::TriggerIndexingWorker::INITIAL_TASK
        Search::Elastic::TriggerIndexingWorker.perform_in(delay, initial_task, OPTIONS)
      end
    end
  end
end
