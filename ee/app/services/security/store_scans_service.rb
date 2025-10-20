# frozen_string_literal: true

module Security
  class StoreScansService
    include ::Gitlab::Utils::StrongMemoize

    def self.execute(pipeline)
      new(pipeline).execute
    end

    def initialize(pipeline)
      @pipeline = pipeline
    end

    def execute
      return if already_purged?

      # StoreGroupedScansService returns true only when it creates a `security_scans` record.
      # To avoid resource wastage we are skipping the reports ingestion when there are no new scans, but
      # we sync the rules as it might cause inconsistent state if we skip.
      results = security_report_artifacts.map do |file_type, artifacts|
        StoreGroupedScansService.execute(artifacts, pipeline, file_type)
      end

      if sbom_report_artifacts.present?
        results += sbom_report_artifacts.map do |file_type, artifacts|
          StoreGroupedSbomScansService.execute(artifacts, pipeline, file_type)
        end

        remove_dangling_dependency_scans
        # We need to set this to ready so that dependency_scanning reports do not keep polling
        # in the event that no dependency scanning reports were processed in `StoreGroupedSbomScansService`.
        ::Vulnerabilities::CompareSecurityReportsService.set_security_report_type_to_ready(
          pipeline_id: pipeline.id,
          report_type: 'dependency_scanning'
        )
      end

      unless results.any?(true)
        schedule_sbom_records if has_sbom_reports? && pipeline.default_branch?

        return
      end

      schedule_store_reports_worker
      schedule_scan_security_report_secrets_worker
      schedule_update_token_status_worker
    end

    private

    attr_reader :pipeline

    delegate :project, to: :pipeline, private: true

    def already_purged?
      pipeline.security_scans.purged.any?
    end

    def grouped_report_artifacts
      pipeline.job_artifacts
        .security_reports(file_types: security_report_file_types)
        .group_by(&:file_type)
    end
    strong_memoize_attr :grouped_report_artifacts

    def security_report_artifacts
      grouped_report_artifacts.reject { |file_type| file_type == 'cyclonedx' || !parse_report_file?(file_type) }
    end
    strong_memoize_attr :security_report_artifacts

    def sbom_report_artifacts
      grouped_report_artifacts['cyclonedx']&.each_with_object({}) do |artifact, object|
        next if artifact.security_report.blank? || !parse_report_file?(artifact.security_report.type.to_s)

        (object[artifact.security_report.type.to_s] ||= []) << artifact
      end
    end
    strong_memoize_attr :sbom_report_artifacts

    def remove_dangling_dependency_scans
      # Security::InitializeSecurityScansServce creates scans in the `created` status as soon as the
      # build completes. However, we can only produce a security report if the SBoM contains source information.
      # After we've ingested findings, the SBoM scans that we were able to produce security reports for
      # will have their status updated to `succeeded` or `job_failed`, and any ones which are still
      # in the `created` status can be removed since the SBoMs must not have source information.
      build_ids = grouped_report_artifacts['cyclonedx']&.pluck(:job_id)

      return if build_ids.blank?

      ::Security::Scan
        .by_scan_types([:dependency_scanning])
        .by_build_ids(build_ids)
        .created
        .delete_all
    end

    def security_report_file_types
      EE::Enums::Ci::JobArtifact.security_report_and_cyclonedx_report_file_types
    end

    def parse_report_file?(file_type)
      project.feature_available?(Ci::Build::LICENSED_PARSER_FEATURES.fetch(file_type))
    end

    def schedule_store_reports_worker
      return unless pipeline.default_branch?

      Gitlab::Redis::SharedState.with do |redis|
        redis.set(Security::StoreSecurityReportsByProjectWorker.cache_key(project_id: project.id), pipeline.id)
      end

      Security::StoreSecurityReportsByProjectWorker.perform_async(project.id)
    end

    def schedule_scan_security_report_secrets_worker
      ScanSecurityReportSecretsWorker.perform_async(pipeline.id) if revoke_secret_detection_token?
    end

    def schedule_update_token_status_worker
      return unless should_update_token_status?

      Security::SecretDetection::GitlabTokenVerificationWorker.perform_async(pipeline.id)
    end

    def should_update_token_status?
      !pipeline.default_branch? &&
        Feature.enabled?(:validity_checks_security_finding_status, project) &&
        Feature.enabled?(:validity_checks, project) &&
        project.security_setting&.validity_checks_enabled &&
        secret_detection_scans_found?
    end

    def revoke_secret_detection_token?
      pipeline.project.public? &&
        ::Gitlab::CurrentSettings.secret_detection_token_revocation_enabled? &&
        secret_detection_scans_found?
    end

    def secret_detection_scans_found?
      pipeline.security_scans.by_scan_types(:secret_detection).any?
    end

    def has_sbom_reports?
      pipeline.self_and_project_descendants.any?(&:has_sbom_reports?)
    end

    def schedule_sbom_records
      ::Sbom::ScheduleIngestReportsService.new(pipeline).execute
    end
  end
end
