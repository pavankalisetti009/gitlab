# frozen_string_literal: true

module Vulnerabilities
  module Archival
    class ArchivedRecordBuilderService
      def self.execute(...)
        new(...).execute
      end

      def initialize(vulnerability_archive, vulnerability)
        @vulnerability_archive = vulnerability_archive
        @vulnerability = vulnerability
        @now = Time.zone.now
      end

      def execute
        Vulnerabilities::ArchivedRecord.new(
          project: project,
          archive: vulnerability_archive,
          vulnerability_identifier: vulnerability.id,
          data: archive_data,
          created_at: now,
          updated_at: now
        )
      end

      private

      attr_reader :vulnerability_archive, :vulnerability, :now

      delegate :project, to: :vulnerability_archive, private: true
      delegate :finding, to: :vulnerability, private: true
      delegate :vulnerability_read, to: :vulnerability, private: true

      def archive_data
        {
          report_type: vulnerability.report_type,
          scanner: finding.scanner.name,
          state: vulnerability.state,
          severity: vulnerability.severity,
          title: vulnerability.title,
          description: finding.description,
          cve_value: vulnerability.cve_value,
          cwe_value: vulnerability.cwe_value,
          other_identifiers: vulnerability.other_identifier_values,
          created_at: vulnerability.created_at.to_s,
          location: vulnerability.location,
          resolved_on_default_branch: vulnerability.resolved_on_default_branch,
          notes_summary: vulnerability.notes_summary,
          full_path: vulnerability.full_path,
          cvss: vulnerability.cvss,
          dismissal_reason: vulnerability_read.dismissal_reason
        }
      end
    end
  end
end
