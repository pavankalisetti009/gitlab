# frozen_string_literal: true

module Sbom
  module Ingestion
    class IngestReportService
      BATCH_SIZE = 10

      def self.execute(pipeline, sbom_report)
        new(pipeline, sbom_report).execute
      end

      def initialize(pipeline, sbom_report)
        @pipeline = pipeline
        @sbom_report = sbom_report
      end

      def execute
        results = occurrence_map_collection.each_slice(BATCH_SIZE).map do |slice|
          ingest_slice(slice)
        end
        build_dependency_graph
        results
      end

      private

      attr_reader :pipeline, :sbom_report

      delegate :project, to: :pipeline, private: true

      def occurrence_map_collection
        @occurrence_map_collection ||= OccurrenceMapCollection.new(sbom_report)
      end

      def ingest_slice(slice)
        IngestReportSliceService.execute(pipeline, slice)
      end

      def build_dependency_graph
        return unless Feature.enabled?(:dependency_paths, project.group)

        ::Sbom::BuildDependencyGraphWorker.perform_async(project.id)
      end
    end
  end
end
