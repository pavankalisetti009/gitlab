# frozen_string_literal: true

module Security
  module AnalyzersStatus
    class UpdateService
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
        return unless executable?

        status_diff = DiffService.new(project, analyzers_statuses).execute
        upsert_analyzers_statuses
        update_ancestors(status_diff)

      rescue StandardError => error
        Gitlab::ErrorTracking.track_exception(error, project_id: project.id, pipeline_id: pipeline.id)
      end

      private

      attr_reader :pipeline, :project

      def executable?
        return unless pipeline.present? && project.present?

        Feature.enabled?(:post_pipeline_analyzer_status_updates, project.root_ancestor)
      end

      def pipeline_builds
        @pipeline_builds ||= ::Security::SecurityJobsFinder.new(pipeline: pipeline)
          .execute
          .with_statuses(Ci::HasStatus::COMPLETED_STATUSES)
          .to_a
      end

      def analyzers_statuses
        @analyzers_statuses ||= pipeline_builds.each_with_object({}) do |build, memo|
          build_analyzer_groups = analyzer_groups_from_build(build)

          build_analyzer_groups&.each do |build_analyzer_group|
            status_data = analyzer_status(build_analyzer_group, build)

            if status_priority(status_data) > status_priority(memo[build_analyzer_group])
              memo[build_analyzer_group] = status_data
            end
          end
        end
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

      def upsert_analyzers_statuses
        processed_types = analyzers_statuses.present? ? analyzers_statuses.keys : []

        AnalyzerProjectStatus.transaction do
          if analyzers_statuses.present?
            AnalyzerProjectStatus.upsert_all(analyzers_statuses.values, unique_by: [:project_id, :analyzer_type])
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

      def update_ancestors(status_diff)
        AncestorsUpdateService.execute(project, status_diff)
      end
    end
  end
end
