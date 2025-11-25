# frozen_string_literal: true

module Security
  module Ingestion
    class FindingMapCollection
      include Gitlab::Utils::StrongMemoize
      include Enumerable

      def initialize(pipeline, security_scan)
        @pipeline = pipeline
        @security_scan = security_scan
      end

      def each
        return to_enum(:each) unless block_given?

        deduplicated_findings.each do |security_finding|
          yield create_finding_map_for(security_finding)
        end
      end

      private

      attr_reader :pipeline, :security_scan

      delegate :findings, :report_findings, :project, to: :security_scan, private: true

      def create_finding_map_for(security_finding)
        # For SAST findings, we override the finding UUID with an existing finding UUID
        # if we have a matching one.
        report_uuid = security_finding.overridden_uuid || security_finding.uuid

        FindingMap.new(
          pipeline,
          tracked_context(pipeline),
          security_finding,
          report_findings_map[report_uuid]
        )
      end

      def report_findings_map
        @report_findings_map ||= report_findings.index_by(&:uuid)
      end

      # Sorting will make sure the findings with `overridden_uuid` values will be
      # processed before the others.
      # We are also sorting by `uuid` to prevent having deadlock errors while
      # ingesting the findings.
      def deduplicated_findings
        @deduplicated_findings ||= findings.deduplicated.except_scanners(sbom_scanner).sort do |a, b|
          [b.overridden_uuid.to_s, b.uuid] <=> [a.overridden_uuid.to_s, a.uuid]
        end
      end

      def sbom_scanner
        @sbom_scanner ||= Vulnerabilities::Scanner.sbom_scanner(project_id: project.id)
      end

      def tracked_context_finder
        @tracked_context_finder ||= TrackedContextFinder.new
      end

      def tracked_context(pipeline)
        return unless set_tracked_context?

        tracked_context_finder.find_or_create_from_pipeline(pipeline)
      end

      def set_tracked_context?
        ::Feature.enabled?(:set_tracked_context_during_ingestion, pipeline.project)
      end
      strong_memoize_attr :set_tracked_context?
    end
  end
end
