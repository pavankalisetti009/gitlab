# frozen_string_literal: true

# TODO: This is dead code and will be removed as part of
# https://gitlab.com/gitlab-org/gitlab/-/issues/450797
module Sbom
  module Ingestion
    class Vulnerabilities
      include Gitlab::Utils::StrongMemoize

      CONTAINER_IMAGE_PATH_PREFIX = 'container-image:'

      attr_reader :pipeline

      delegate :project, to: :pipeline

      def initialize(pipeline)
        @pipeline = pipeline
      end

      # Retrieves vulnerability info for the given package.
      # Note: Builds the full vulnerability info map on first call.
      def fetch(name, version, path)
        key = [name, version, path]
        vulnerabilities_info.fetch(key, { vulnerability_ids: [], highest_severity: nil })
      end

      private

      def vulnerabilities_info
        @vulnerabilities_info ||= build_vulnerabilities_info
      end

      def build_vulnerabilities_info
        vulnerability_findings.each_with_object({}) do |finding, info|
          dependency = finding.location["dependency"]
          next unless dependency

          key = [
            dependency.dig('package', 'name'),
            dependency['version'],
            dependency_path(finding)
          ]

          info[key] ||= { vulnerability_ids: [], highest_severity: finding.severity }
          info[key][:vulnerability_ids] << finding.vulnerability_id

          current_severity_value = ::Enums::Vulnerability::SEVERITY_LEVELS[info.dig(key, :highest_severity)]
          new_severity_value = ::Enums::Vulnerability::SEVERITY_LEVELS[finding.severity]
          info[key][:highest_severity] = finding.severity if new_severity_value > current_severity_value
        end
      end

      def vulnerability_findings
        project
          .vulnerability_findings
          .by_report_types(%i[container_scanning dependency_scanning])
      end
      strong_memoize_attr :vulnerability_findings

      def dependency_path(finding)
        return finding.file if finding.dependency_scanning?

        "#{CONTAINER_IMAGE_PATH_PREFIX}#{finding.image}"
      end
    end
  end
end
