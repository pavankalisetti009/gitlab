# frozen_string_literal: true

module Security
  module Ingestion
    # This service class takes the IDs of recently ingested
    # vulnerabilities for a project which had been previously
    # detected by the same scanner, and marks them as resolved
    # on the default branch if they were not detected again.
    class MarkAsResolvedService
      include Gitlab::InternalEventsTracking
      include Gitlab::Utils::StrongMemoize

      CVS_SCANNER_EXTERNAL_ID = 'gitlab-sbom-vulnerability-scanner'
      CS_SCANNERS_EXTERNAL_IDS = %w[trivy].freeze
      DS_SCANNERS_EXTERNAL_IDS = %w[gemnasium gemnasium-maven gemnasium-python].freeze

      BATCH_SIZE = 1000
      AUTO_RESOLVE_LIMIT = 1000

      def self.execute(scanner, ingested_ids)
        new(scanner, ingested_ids).execute
      end

      def initialize(scanner, ingested_ids)
        @scanner = scanner
        @ingested_ids = ingested_ids
        @auto_resolved_count = 0
      end

      def execute
        return unless scanner

        vulnerability_reads
          .by_scanner(scanner)
          .each_batch(of: BATCH_SIZE) { |batch| process_batch(batch) }

        if scanner_for_container_scanning?
          process_existing_cvs_vulnerabilities_for_container_scanning
        elsif scanner_for_dependency_scanning?
          process_existing_cvs_vulnerabilities_for_dependency_scanning
        end
      end

      private

      attr_accessor :auto_resolved_count
      attr_reader :ingested_ids, :scanner

      delegate :project, to: :scanner, private: true
      delegate :vulnerability_reads, to: :project, private: true

      def process_batch(batch)
        (batch.pluck_primary_key - ingested_ids).then do |missing_ids|
          mark_as_no_longer_detected(missing_ids)
          auto_resolve(missing_ids)
        end
      end

      def mark_as_no_longer_detected(missing_ids)
        return if missing_ids.blank?

        resolved_count = Vulnerability.id_in(missing_ids)
          .with_resolution(false)
          .not_requiring_manual_resolution
          .update_all(resolved_on_default_branch: true)

        track_no_longer_detected_vulnerabilities(resolved_count)
      end

      def auto_resolve(missing_ids)
        return unless auto_resolve_enabled?
        return unless auto_resolved_count < AUTO_RESOLVE_LIMIT

        result = Vulnerabilities::AutoResolveService.new(project, missing_ids).execute

        @auto_resolved_count += result.payload[:count] if result.success?
      end

      def auto_resolve_enabled?
        ::Feature.enabled?(:auto_resolve_vulnerabilities, project)
      end
      strong_memoize_attr :auto_resolve_enabled?

      def process_existing_cvs_vulnerabilities_for_container_scanning
        vulnerability_reads
          .by_scanner_ids(cvs_scanner_id)
          .with_report_types(:container_scanning)
          .each_batch { |batch| process_batch(batch) }
      end

      def process_existing_cvs_vulnerabilities_for_dependency_scanning
        vulnerability_reads
          .by_scanner_ids(cvs_scanner_id)
          .with_report_types(:dependency_scanning)
          .each_batch { |batch| process_batch(batch) }
      end

      def cvs_scanner_id
        ::Vulnerabilities::Scanner.for_projects(project.id)
          .with_external_id(CVS_SCANNER_EXTERNAL_ID)
          .pluck_primary_key
      end

      def scanner_for_container_scanning?
        scanner.external_id.in?(CS_SCANNERS_EXTERNAL_IDS)
      end

      def scanner_for_dependency_scanning?
        scanner.external_id.in?(DS_SCANNERS_EXTERNAL_IDS)
      end

      def track_no_longer_detected_vulnerabilities(count)
        Gitlab::InternalEvents.with_batched_redis_writes do
          count.times do
            track_internal_event(
              'vulnerability_no_longer_detected_on_default_branch',
              project: project
            )
          end
        end
      end
    end
  end
end
