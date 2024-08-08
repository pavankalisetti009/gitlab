# frozen_string_literal: true

module Dependencies
  module ExportSerializers
    class ProjectDependenciesService
      def self.execute(dependency_list_export)
        new(dependency_list_export).execute
      end

      def initialize(dependency_list_export)
        @dependency_list_export = dependency_list_export
      end

      def execute
        DependencyListEntity.represent(dependencies_list, serializer_parameters)
      end

      private

      attr_reader :dependency_list_export

      delegate :project, :author, to: :dependency_list_export, private: true

      def dependencies_list
        ::Sbom::DependenciesFinder.new(project, params: default_filters).execute
          .with_component
          .with_version
          .with_vulnerabilities
      end

      def default_filters
        { source_types: default_source_type_filters }
      end

      def default_source_type_filters
        ::Sbom::Source::DEFAULT_SOURCES.keys + [nil]
      end

      def pipeline
        @pipeline ||= project.latest_ingested_sbom_pipeline
      end

      def job_artifacts
        ::Ci::JobArtifact.of_report_type(:dependency_list)
      end

      def serializer_parameters
        {
          request: EntityRequest.new({ project: project, user: author }),
          pipeline: pipeline,
          project: project,
          include_vulnerabilities: true
        }
      end
    end
  end
end
