# frozen_string_literal: true

module Security
  module Ingestion
    module Tasks
      class IngestCvsSecurityScanners < AbstractTask
        include Gitlab::Ingestion::BulkInsertableTask

        self.model = Vulnerabilities::Scanner
        self.unique_by = %i[project_id external_id].freeze
        self.uses = %i[project_id id]

        private

        def attributes
          finding_maps.map do |finding_map|
            {
              project_id: finding_map.project.id,
              external_id: Gitlab::VulnerabilityScanning::SecurityScanner::EXTERNAL_ID,
              name: Gitlab::VulnerabilityScanning::SecurityScanner::NAME,
              vendor: Gitlab::VulnerabilityScanning::SecurityScanner::VENDOR
            }.freeze
          end
        end

        def after_ingest
          finding_maps.each do |finding_map|
            finding_map.scanner_id = get_scanner_id(finding_map)
          end
        end

        def indexed_return_data
          @indexed_return_data ||= return_data.to_h
        end

        def get_scanner_id(finding_map)
          indexed_return_data[finding_map.project.id]
        end
      end
    end
  end
end
