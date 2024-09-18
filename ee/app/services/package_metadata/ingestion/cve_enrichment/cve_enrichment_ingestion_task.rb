# frozen_string_literal: true

module PackageMetadata
  module Ingestion
    module CveEnrichment
      class CveEnrichmentIngestionTask
        Error = Class.new(StandardError)

        def self.execute(import_data)
          new(import_data).execute
        end

        def initialize(import_data)
          @import_data = import_data
        end

        def execute
          PackageMetadata::Epss.bulk_upsert!(valid_cve_enrichment_entries, unique_by: %w[cve],
            returns: %w[id cve score created_at updated_at])
        end

        private

        attr_reader :import_data

        # validates the list of provided cve_enrichment models and returns
        # only those which are valid and logs the invalid packages as an error
        def valid_cve_enrichment_entries
          cve_enrichment.map do |cve_enrichment_entry|
            if cve_enrichment_entry.invalid?
              Gitlab::ErrorTracking.track_exception(
                Error.new(
                  "invalid CVE enrichment entry"),
                cve: cve_enrichment_entry.cve,
                score: cve_enrichment_entry.score,
                errors: cve_enrichment_entry.errors.to_hash
              )
              next
            end

            cve_enrichment_entry
          end.reject(&:blank?)
        end

        def cve_enrichment
          import_data.map do |data_object|
            PackageMetadata::Epss.new(
              cve: data_object.cve_id,
              score: data_object.epss_score,
              created_at: now,
              updated_at: now
            )
          end
        end

        def now
          @now ||= Time.zone.now
        end
      end
    end
  end
end
