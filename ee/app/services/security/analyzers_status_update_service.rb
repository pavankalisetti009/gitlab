# frozen_string_literal: true

module Security
  class AnalyzersStatusUpdateService
    BUILD_TO_ANALYZER_STATUS = {
      "success" => "success",
      "failed" => "failed",
      "canceled" => "failed",
      "skipped" => "failed"
    }.freeze

    STATUS_PRIORITY = {
      "failed" => 2,
      "success" => 1,
      "not_configured" => 0
    }.freeze

    def initialize(pipeline)
      @pipeline = pipeline
      @project = pipeline&.project
    end

    def execute
      return unless pipeline.present? && project.present?
      return unless Feature.enabled?(:post_pipeline_analyzer_status_updates, project.root_ancestor)

      analyzers_statuses = process_builds(pipeline_builds)
      upsert_analyzer_statuses(analyzers_statuses)
    rescue StandardError => error
      Gitlab::ErrorTracking.track_exception(error, project_id: project.id, pipeline_id: pipeline.id)
    end

    private

    attr_reader :pipeline, :project

    def pipeline_builds
      jobs_relation = ::Security::SecurityJobsFinder.new(
        pipeline: pipeline
      ).execute
      jobs_relation.with_statuses(Ci::HasStatus::COMPLETED_STATUSES)
    end

    def process_builds(builds)
      return {} unless builds.present?

      analyzer_statuses = {}
      builds.find_each do |build|
        build_analyzer_groups = analyzer_groups_from_build(build)
        build_analyzer_groups&.each do |build_analyzer_group|
          status_data = analyzer_status(build_analyzer_group, build)
          if status_priority(status_data) > status_priority(analyzer_statuses[build_analyzer_group])
            analyzer_statuses[build_analyzer_group] = status_data
          end
        end
      end

      analyzer_statuses
    end

    def analyzer_groups_from_build(build)
      report_artifacts = build_reports(build)
      existing_group_types = report_artifacts & Enums::Security.analyzer_types.keys
      normalize_sast_analyzers(build, existing_group_types)
    end

    def normalize_sast_analyzers(build, existing_group_types)
      return existing_group_types unless existing_group_types.include?(:sast)

      # Because :sast_iac and :sast_advanced reports belong to a report with a name of 'sast',
      # we have to do extra checking to determine which reports have been included
      existing_group_types.push(:sast_advanced) if build.name == 'gitlab-advanced-sast'

      # kics-iac-sast is being treated as IaC and not as SAST
      if build.name == 'kics-iac-sast'
        existing_group_types.push(:sast_iac)
        existing_group_types.delete(:sast)
      end

      existing_group_types
    end

    def analyzer_status(type, build)
      {
        project_id: project.id,
        traversal_ids: traversal_ids,
        analyzer_type: type,
        status: BUILD_TO_ANALYZER_STATUS[build.status] || :not_configured,
        last_call: build.started_at
      }
    end

    def upsert_analyzer_statuses(analyzer_statuses)
      processed_types = analyzer_statuses.present? ? analyzer_statuses.keys : []

      AnalyzerProjectStatus.transaction do
        if analyzer_statuses.present?
          AnalyzerProjectStatus.upsert_all(analyzer_statuses.values, unique_by: [:project_id, :analyzer_type])
        end

        AnalyzerProjectStatus.by_projects(project).without_types(processed_types)
          .update_all(status: :not_configured)
      end
    end

    def traversal_ids
      @traversal_ids ||= project.namespace.traversal_ids
    end

    def build_reports(build)
      build.options[:artifacts][:reports].keys
    end

    def status_priority(status_data)
      STATUS_PRIORITY[status_data&.dig(:status)] || -1
    end
  end
end
