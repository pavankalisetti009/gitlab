# frozen_string_literal: true

module Security
  module Ingestion
    def self.ingest_pipeline?(pipeline)
      return true if pipeline.default_branch?
      return false unless ::Feature.enabled?(:vulnerabilities_across_contexts, pipeline.project)

      Security::ProjectTrackedContext.tracked_pipeline?(pipeline)
    end
  end
end
