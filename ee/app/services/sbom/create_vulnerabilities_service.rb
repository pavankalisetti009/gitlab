# frozen_string_literal: true

module Sbom
  class CreateVulnerabilitiesService
    include Gitlab::Utils::StrongMemoize
    include Gitlab::VulnerabilityScanning::AdvisoryUtils

    def self.execute(pipeline_id)
      new(pipeline_id).execute
    end

    def initialize(pipeline_id)
      @pipeline_id = pipeline_id
    end

    def execute
      occurrences.each_batch do |occurrence_batch|
        affected_packages(occurrence_batch).each_batch do |affected_package_batch|
          affected_package_batch.each do |affected_package|
            # We need to match every affected package to one occurrence
            affected_occurrence = occurrence_batch.find do |occurrence|
              next unless affected_package.package_name == occurrence.component_name

              affected_occurrences?(occurrence, affected_package)
            end

            next unless affected_occurrence.present?

            advisory_data_object = Gitlab::VulnerabilityScanning::Advisory.from_affected_package(
              affected_package: affected_package, advisory: affected_package.advisory)
            create_vulnerabilities(advisory: advisory_data_object, affected_components: [affected_occurrence])
          end
        end
      end
    end

    attr_reader :pipeline_id

    private

    def affected_occurrences?(occurrence, affected_package)
      advisory = affected_package.advisory

      occurrence_is_affected?(
        xid: advisory.advisory_xid,
        purl_type: affected_package.purl_type,
        range: affected_package.affected_range,
        version: occurrence.version,
        distro: affected_package.distro_version,
        source: occurrence.source,
        project_id: occurrence.project_id,
        source_xid: advisory.source_xid
      )
    end

    def affected_packages(occurrence_batch)
      ::PackageMetadata::AffectedPackage.for_occurrences(occurrence_batch).with_advisory
    end

    def occurrences
      Sbom::Occurrence
        .by_pipeline_ids(pipeline_id)
        .with_component_source_version_and_project
        .with_pipeline_project_and_namespace
        .filter_by_non_nil_component_version
    end
    strong_memoize_attr :occurrences
  end
end
