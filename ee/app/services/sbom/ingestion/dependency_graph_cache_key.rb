# frozen_string_literal: true

module Sbom
  module Ingestion
    class DependencyGraphCacheKey
      attr_reader :project, :sbom_report

      def initialize(project, sbom_report)
        @project = project
        @sbom_report = sbom_report
      end

      def key
        return @cache_key if defined?(@cache_key)

        components = sbom_report.components
          .sort_by(&:ref)
          .reduce("") { |agg, component| agg + component.ref }

        @cache_key ||= OpenSSL::Digest::SHA256.hexdigest(project.id.to_s + components)
      end
    end
  end
end
