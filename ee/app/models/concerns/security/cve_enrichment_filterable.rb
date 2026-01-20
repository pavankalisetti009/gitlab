# frozen_string_literal: true

# This concern provides shared CVE enrichment filtering logic
# for both Security::Finding and Vulnerabilities::Finding models.
module Security
  module CveEnrichmentFilterable
    extend ActiveSupport::Concern

    included do
      scope :with_cve_enrichment_filters, ->(
        known_exploited: nil, epss_operator: nil, epss_value: nil, include_findings_with_unenriched_cves: nil
      ) do
        has_enrichment_filters = known_exploited == true || (epss_operator && epss_value)
        has_unenriched_filter = include_findings_with_unenriched_cves == true

        break none unless has_enrichment_filters || has_unenriched_filter

        enrichment_scopes = []

        if has_enrichment_filters
          enrichment_scopes << Security::FindingEnrichment.with_enrichment_filters(
            known_exploited: known_exploited,
            epss_operator: epss_operator,
            epss_value: epss_value
          )
        end

        enrichment_scopes << Security::FindingEnrichment.without_enrichment_data if has_unenriched_filter

        where(
          Security::FindingEnrichment
            .where(Security::FindingEnrichment.arel_table[:finding_uuid].eq(arel_table[:uuid]))
            .merge(enrichment_scopes.reduce(&:or))
            .arel
            .exists
        )
      end
    end
  end
end
