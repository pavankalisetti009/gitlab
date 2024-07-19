# frozen_string_literal: true

module Sbom
  class MergeReportsService
    attr_reader :merged_report, :reports

    def initialize(reports)
      @reports = reports

      @merged_report = ::Gitlab::Ci::Reports::Sbom::Report.new

      @all_tools = {}
      @all_authors = {}
      @all_properties = {}
      @all_components = {}
    end

    def execute
      reports.each do |report|
        add_tools_for(report)
        report.metadata.authors.each { |e| @all_authors[e] = 1 }
        report.metadata.properties.each { |e| @all_properties[e] = 1 }

        add_sbom_components_for(report)
      end

      merged_report.metadata.timestamp = Time.current.as_json
      merged_report.metadata.tools = @all_tools.keys
      merged_report.metadata.authors = @all_authors.keys
      merged_report.metadata.properties = @all_properties.keys
      merged_report.components = @all_components.keys

      merged_report
    end

    private

    def add_sbom_components_for(report)
      component_with_licenses_for(report).each do |component|
        component.type = 'library'
        component.purl = "pkg:#{component.purl_type}/#{component.name}@#{component.version}"

        @all_components[component] = 1
      end
    end

    def component_with_licenses_for(report)
      ::Gitlab::LicenseScanning::PackageLicenses.new(components: report.components).fetch
    end

    def add_tools_for(report)
      if report.metadata.tools.is_a? Array
        report.metadata.tools.each { |e| @all_tools[e] = 1 }
      else
        report.metadata.tools&.dig(:components)&.each { |e| @all_tools[convert_tool_into_deprecated_form(e)] = 1 }
      end
    end

    # Spec 1.4 of CycloneDX requires the old tool object structure
    def convert_tool_into_deprecated_form(tool)
      {
        vendor: tool[:group],
        name: tool[:name],
        version: tool[:version]
      }
    end
  end
end
