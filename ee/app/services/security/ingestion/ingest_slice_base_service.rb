# frozen_string_literal: true

module Security
  module Ingestion
    class IngestSliceBaseService
      include Gitlab::Utils::StrongMemoize

      def self.execute(pipeline, finding_maps)
        new(pipeline, finding_maps).execute
      end

      def initialize(pipeline, finding_maps)
        @pipeline = pipeline
        @finding_maps = finding_maps
      end

      def execute
        ::Gitlab::Database::SecApplicationRecord.transaction do
          self.class::SEC_DB_TASKS.each { |task| execute_task(task) }
        end

        context.run_sec_after_commit_tasks

        ::ApplicationRecord.transaction do
          self.class::MAIN_DB_TASKS.each { |task| execute_task(task) }
        end

        finding_maps.map(&:vulnerability_id)
      end

      private

      attr_reader :pipeline, :finding_maps

      def execute_task(task)
        Tasks.const_get(task, false).execute(pipeline, finding_maps, context)
      end

      def context
        Context.new
      end
      strong_memoize_attr :context
    end
  end
end
