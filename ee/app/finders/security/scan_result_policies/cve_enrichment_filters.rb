# frozen_string_literal: true

# This module provides shared CVE enrichment filtering logic
# for both Security::ScanResultPolicies::FindingsFinder and Security::ScanResultPolicies::VulnerabilitiesFinder.
module Security
  module ScanResultPolicies
    module CveEnrichmentFilters
      private

      def apply_cve_enrichment_filters(records)
        records.with_cve_enrichment_filters(
          known_exploited: params[:known_exploited],
          epss_operator: params.dig(:epss_score, :operator),
          epss_value: params.dig(:epss_score, :value),
          include_findings_with_unenriched_cves: include_findings_with_unenriched_cves?
        )
      end

      def valid_cve_enrichment_params?
        return false unless ::Feature.enabled?(:security_policies_kev_filter, project)

        params[:known_exploited] == true ||
          ::Security::ScanResultPolicy.epss_score_valid?(params[:epss_score]) ||
          include_findings_with_unenriched_cves?
      end

      def include_findings_with_unenriched_cves?
        params[:enrichment_data_unavailable_action] == 'block'
      end
    end
  end
end
