# frozen_string_literal: true

module Sbom
  module Ingestion
    class IngestReportsService
      include Gitlab::ExclusiveLeaseHelpers
      include Gitlab::Utils::StrongMemoize

      # Typical job finishes in 1-2 minutes, but has been observed
      # to take up to 20 minutes in the worst case.
      LEASE_TTL = 30.minutes

      # 10 retries at 6 seconds each will allow 95% of jobs to acquire a lease
      # without raising FailedToObtainLockError. When waiting for exceptionally long jobs,
      # we'll allow the job to raise and be retried by sidekiq.
      LEASE_TRY_AFTER = 6.seconds

      def self.execute(pipeline)
        new(pipeline).execute
      end

      def initialize(pipeline)
        @pipeline = pipeline
      end

      def execute
        in_lock(lease_key, ttl: LEASE_TTL, sleep_sec: LEASE_TRY_AFTER) do
          ingest_reports.then do |ingested_ids|
            delete_not_present_occurrences(ingested_ids) unless container_scanning_for_registry_pipeline?

            if ingested_ids.present? && Feature.enabled?(:dependency_scanning_using_sbom_reports, project)
              publish_ingested_sbom_event
            end
          end

          project.set_latest_ingested_sbom_pipeline_id(pipeline.id)

          break unless Feature.enabled?(:store_sbom_report_ingestion_errors, project) && sbom_report_errors

          pipeline.set_sbom_report_ingestion_errors(sbom_report_errors)
        end
      end

      private

      attr_reader :pipeline

      delegate :project, to: :pipeline, private: true

      # We only ingest one sbom report in container_scanning_for_registry jobs.
      # This is a temprory quick fix for https://gitlab.com/gitlab-org/gitlab/-/issues/478376.
      def container_scanning_for_registry_pipeline?
        valid_sbom_reports&.first&.source&.source_type == :container_scanning_for_registry
      end
      strong_memoize_attr :container_scanning_for_registry_pipeline?

      def ingest_reports
        valid_sbom_reports.flat_map { |report| ingest_report(report) }
      end

      def all_sbom_reports
        @all_sbom_reports ||= pipeline.sbom_reports(self_and_project_descendants: true).reports
      end

      def valid_sbom_reports
        all_sbom_reports.select(&:valid?)
      end

      def sbom_report_errors
        return unless invalid_sbom_reports.any?

        invalid_sbom_reports.map(&:errors)
      end
      strong_memoize_attr :sbom_report_errors

      def invalid_sbom_reports
        @invalid_sbom_reports ||= all_sbom_reports.reject(&:valid?)
      end

      def ingest_report(sbom_report)
        IngestReportService.execute(pipeline, sbom_report, vulnerabilities_info)
      end

      def delete_not_present_occurrences(ingested_occurrence_ids)
        DeleteNotPresentOccurrencesService.execute(pipeline, ingested_occurrence_ids)
      end

      def vulnerabilities_info
        return {} if ::Feature.enabled?(:deprecate_vulnerability_occurrence_pipelines, project)

        @vulnerabilities_info ||= Sbom::Ingestion::Vulnerabilities.new(pipeline)
      end

      def publish_ingested_sbom_event
        Gitlab::EventStore.publish(
          Sbom::SbomIngestedEvent.new(data: { pipeline_id: pipeline.id })
        )
      end

      def lease_key
        Sbom::Ingestion.project_lease_key(project.id)
      end
    end
  end
end
