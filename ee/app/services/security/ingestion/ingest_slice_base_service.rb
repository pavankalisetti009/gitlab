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
        run_tasks_in_sec_db
        run_tasks_in_main_db

        update_elasticsearch

        vulnerability_ids
      end

      private

      attr_reader :pipeline, :finding_maps

      def run_tasks_in_sec_db
        ::SecApplicationRecord.transaction do
          project = pipeline&.project

          feature_enabled = Feature.enabled?(:turn_off_vulnerability_read_create_db_trigger_function,
            project || :instance)

          ::SecApplicationRecord.connection.execute("SELECT set_config(
          'vulnerability_management.dont_execute_db_trigger', '#{feature_enabled}', true);")

          self.class::SEC_DB_TASKS.each { |task| execute_task(task) }
        end
      end

      def run_tasks_in_main_db
        ::ApplicationRecord.transaction do
          self.class::MAIN_DB_TASKS.each { |task| execute_task(task) }
        end
      end

      def execute_task(task)
        Tasks.const_get(task, false).execute(pipeline, finding_maps)
      end

      def update_elasticsearch
        vulnerabilities = Vulnerability.id_in(vulnerability_ids)

        ::Vulnerabilities::BulkEsOperationService.new(vulnerabilities).execute(&:itself)
      end

      def vulnerability_ids
        @vulnerability_ids ||= finding_maps.map(&:vulnerability_id)
      end
    end
  end
end
