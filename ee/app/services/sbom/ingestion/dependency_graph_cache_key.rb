# frozen_string_literal: true

module Sbom
  module Ingestion
    class DependencyGraphCacheKey
      def initialize(project, sbom_report)
        @project = project
        @sbom_report = sbom_report
      end

      def key
        return @cache_key if defined?(@cache_key)

        components = sbom_report.components
          .sort_by(&:ref)
          .map { |component| reduce_component(component) }
          .join

        @cache_key ||= OpenSSL::Digest::SHA256.hexdigest(project.id.to_s + components)
      end

      private

      attr_reader :project, :sbom_report

      def reduce_component(component)
        ancestors = component.ancestors
          .reject(&:empty?)
          .map { |ancestor| ancestor[:name] + ancestor[:version] }
          .join

        component.ref.to_s + ancestors
      end
    end
  end
end
