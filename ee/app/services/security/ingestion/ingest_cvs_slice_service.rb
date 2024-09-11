# frozen_string_literal: true

module Security
  module Ingestion
    class IngestCvsSliceService < IngestSliceBaseService
      TASKS = %i[
        IngestCvsSecurityScanners
        IngestIdentifiers
        IngestFindings
        IngestVulnerabilities
        IncreaseCountersTask
        AttachFindingsToVulnerabilities
        IngestFindingIdentifiers
        IngestFindingLinks
        IngestFindingSignatures
        IngestFindingEvidence
        IngestVulnerabilityFlags
        IngestVulnerabilityReads
        MarkCvsProjectsAsVulnerable
        IngestVulnerabilityStatistics
        HooksExecution
      ].freeze

      def self.execute(finding_maps)
        super(nil, finding_maps)
      end
    end
  end
end
