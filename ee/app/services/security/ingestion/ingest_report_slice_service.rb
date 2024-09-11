# frozen_string_literal: true

module Security
  module Ingestion
    # Base class to organize the chain of responsibilities
    # for the report slice.
    #
    # Returns the ingested vulnerability IDs.
    class IngestReportSliceService < IngestSliceBaseService
      TASKS = %i[
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
        IngestVulnerabilityStatistics
        IngestRemediations
        HooksExecution
      ].freeze

      def execute
        Security::Ingestion::Tasks::UpdateVulnerabilityUuids.execute(@pipeline, @finding_maps)

        super
      end
    end
  end
end
