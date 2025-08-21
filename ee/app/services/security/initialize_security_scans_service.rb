# frozen_string_literal: true

module Security
  # InitializeSecurityScansService creates Security::Scan records with the :created status.
  # This is done immediately after the Ci::Build completes so that we can indicate when a pipeline
  # contains a scan without any delay. When the pipeline completes, we asynchronously enqueue
  # Security::StoreScansWorker which will do further processing and progress to later statuses.
  class InitializeSecurityScansService
    def self.execute(build)
      new(build).execute
    end

    def initialize(build)
      @build = build
    end

    def execute
      Security::Scan.bulk_insert!(insert_objects, unique_by: %i[build_id scan_type], skip_duplicates: true)
    end

    private

    attr_reader :build

    delegate :pipeline, to: :build

    def insert_objects
      scan_types.map do |scan_type|
        Security::Scan.new(
          build: build,
          scan_type: scan_type,
          status: :created,
          created_at: pipeline.security_scans_created_at,
          updated_at: Time.current,
          findings_partition_number: pipeline.security_findings_partition_number,
          project_id: build.project_id,
          pipeline_id: build.commit_id
        )
      end
    end

    def scan_types
      scan_types = build
        .security_report_artifacts
        .map(&:file_type)
        .to_set

      scan_types.add('dependency_scanning') if scan_types.delete?('cyclonedx')

      scan_types
    end
  end
end
