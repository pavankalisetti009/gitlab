# frozen_string_literal: true

module Security
  module Ingestion
    module Tasks
      class IngestCvsSecurityScanners < AbstractTask
        include Gitlab::Ingestion::BulkInsertableTask
        include Gitlab::Utils::StrongMemoize

        self.model = Vulnerabilities::Scanner
        self.unique_by = %i[project_id external_id].freeze
        self.uses = %i[id project_id]

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
          return_data.to_h do |(scanner_id, project_id)|
            [project_id, scanner_id]
          end
        end
        strong_memoize_attr :indexed_return_data

        def get_scanner_id(finding_map)
          indexed_return_data[finding_map.project.id]
        end
      end
    end
  end
end
