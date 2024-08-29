# frozen_string_literal: true

module Sbom
  class CreateVulnerabilitiesService
    include Gitlab::Utils::StrongMemoize
    include Gitlab::VulnerabilityScanning::AdvisoryUtils

    BATCH_SIZE = 1000

    def self.execute(pipeline_id)
      new(pipeline_id).execute
    end

    def initialize(pipeline_id)
      @pipeline_id = pipeline_id
    end

    def execute
      valid_sbom_reports.each do |sbom_report|
        next unless sbom_report.source.present?

        sbom_report.components.each_slice(BATCH_SIZE) do |occurrence_batch|
          affected_packages(occurrence_batch).each_batch do |affected_package_batch|
            finding_maps = affected_package_batch.filter_map do |affected_package|
              # We need to match every affected package to one occurrence
              affected_occurrence = occurrence_batch.find do |occurrence|
                next unless affected_package.package_name == occurrence.name

                affected_occurrence?(occurrence, sbom_report.source, affected_package)
              end

              next unless affected_occurrence.present?

              advisory_data_object = Gitlab::VulnerabilityScanning::Advisory.from_affected_package(
                affected_package: affected_package, advisory: affected_package.advisory)

              Security::VulnerabilityScanning::BuildFindingMapService.execute(
                advisory: advisory_data_object,
                affected_component: affected_occurrence,
                source: sbom_report.source,
                pipeline: pipeline,
                project: project,
                purl_type: affected_occurrence.purl.type)
            end

            create_vulnerabilities(finding_maps)
          end
        end
      end
    end

    attr_reader :pipeline_id

    private

    def affected_occurrence?(occurrence, source, affected_package)
      advisory = affected_package.advisory

      occurrence_is_affected?(
        xid: advisory.advisory_xid,
        purl_type: affected_package.purl_type,
        range: affected_package.affected_range,
        version: occurrence.version,
        distro: affected_package.distro_version,
        source: source,
        project_id: pipeline.project_id,
        source_xid: advisory.source_xid
      )
    end

    def affected_packages(occurrence_batch)
      ::PackageMetadata::AffectedPackage.for_occurrences(occurrence_batch).with_advisory
    end

    def all_sbom_reports
      pipeline.sbom_reports(self_and_project_descendants: true).reports
    end

    def valid_sbom_reports
      all_sbom_reports.select(&:valid?)
    end
    strong_memoize_attr :valid_sbom_reports

    def pipeline
      Ci::Pipeline.find(pipeline_id)
    end
    strong_memoize_attr :pipeline

    def project
      pipeline.project
    end
    strong_memoize_attr :project
  end
end
