# frozen_string_literal: true

module Security
  module Ingestion
    class IngestSliceBaseService
      def self.execute(pipeline, finding_maps)
        new(pipeline, finding_maps).execute
      end

      def initialize(pipeline, finding_maps)
        @pipeline = pipeline
        @finding_maps = finding_maps
      end

      def execute
        Gitlab::Database::QueryAnalyzers::PreventCrossDatabaseModification.temporary_ignore_tables_in_transaction(
          %w[
            project_statistics
            security_findings
            vulnerabilities
            vulnerability_flags
            vulnerability_finding_evidences
            vulnerability_finding_links
            vulnerability_finding_signatures
            vulnerability_findings_remediations
            vulnerability_identifiers
            vulnerability_occurrences
            vulnerability_occurrence_identifiers
            vulnerability_occurrence_pipelines
            vulnerability_reads
            vulnerability_remediations
            vulnerability_scanners
            vulnerability_statistics
          ], url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/474635'
        ) do
          ApplicationRecord.transaction do
            self.class::TASKS.each { |task| execute_task(task) }
          end

          finding_maps.map(&:vulnerability_id)
        end
      end

      private

      attr_reader :pipeline, :finding_maps

      def execute_task(task)
        Tasks.const_get(task, false).execute(pipeline, finding_maps)
      end
    end
  end
end
