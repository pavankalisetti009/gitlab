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
        # This will halt execution of this slice but we will keep calling this service
        # for the rest of the finding maps.
        return [] unless quota.validate!

        Security::Ingestion::Tasks::UpdateVulnerabilityUuids.execute(@pipeline, @finding_maps)

        super
      end

      private

      def quota
        pipeline.project.vulnerability_quota
      end
    end
  end
end
