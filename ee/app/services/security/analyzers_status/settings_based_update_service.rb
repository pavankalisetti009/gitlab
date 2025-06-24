# frozen_string_literal: true

module Security
  module AnalyzersStatus
    class SettingsBasedUpdateService
      include ::Security::AnalyzersStatus::AggregatedTypesHandler

      def self.execute(project_ids, analyzer_type)
        new(project_ids, analyzer_type).execute
      end

      def initialize(project_ids, analyzer_type)
        @project_ids = project_ids
        @analyzer_type = analyzer_type.to_sym
      end

      def execute
        return unless TYPE_MAPPINGS[analyzer_type].present? && projects.present?

        upsert_analyzers_statuses
      end

      private

      attr_reader :project_ids, :analyzer_type

      def projects
        return [] unless project_ids.present?

        @projects ||= begin
          unfiltered_projects = Project.id_in(project_ids).with_security_setting.with_namespaces.with_analyzer_statuses
          filter_feature_enabled_projects(unfiltered_projects)
        end
      end

      def analyzers_statuses
        @analyzers_statuses ||= projects.flat_map do |project|
          setting_field = TYPE_MAPPINGS[@analyzer_type][:setting_field]
          setting_enabled = project.security_setting&.read_attribute(setting_field) || false
          setting_status = status_to_symbol(setting_enabled)

          [
            build_analyzer_status_hash(project, TYPE_MAPPINGS[@analyzer_type][:setting_type], setting_status),
            build_aggregated_type_status(project, TYPE_MAPPINGS[@analyzer_type][:setting_type], setting_status)
          ].compact
        end
      end

      def upsert_analyzers_statuses
        return unless analyzers_statuses.present?

        AnalyzerProjectStatus.upsert_all(analyzers_statuses, unique_by: [:project_id, :analyzer_type])
      end

      def status_to_symbol(status)
        status ? :success : :not_configured
      end

      def filter_feature_enabled_projects(projects)
        # Validate the feature flag once per root ancestor
        projects
          .group_by(&:root_ancestor)
          .select { |root_ancestor, _| Feature.enabled?(:post_pipeline_analyzer_status_updates, root_ancestor) }
          .values.flatten
      end
    end
  end
end
