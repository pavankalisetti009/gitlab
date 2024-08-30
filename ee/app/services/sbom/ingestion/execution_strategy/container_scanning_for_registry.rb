# frozen_string_literal: true

module Sbom
  module Ingestion
    module ExecutionStrategy
      class ContainerScanningForRegistry < Default
        def execute
          ingest_reports

          publish_ingested_sbom_event
        end
      end
    end
  end
end
