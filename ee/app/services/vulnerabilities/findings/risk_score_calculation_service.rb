# frozen_string_literal: true

module Vulnerabilities
  module Findings
    class RiskScoreCalculationService
      attr_reader :vulnerabilities

      BATCH_SIZE = 1000

      def self.calculate_for(vulnerability)
        new([vulnerability.id]).execute
      end

      def initialize(vulnerability_ids)
        @vulnerability_ids = vulnerability_ids
      end

      def execute
        findings = Vulnerabilities::Finding.with_cve_enrichments.by_vulnerability(@vulnerability_ids)
        findings_to_update = filter_findings_by_feature_flag(findings)

        findings_to_update.each_slice(BATCH_SIZE) do |findings_batch|
          risk_scores = findings_batch.map do |finding|
            {
              finding_id: finding.id,
              project_id: finding.project_id,
              risk_score: Vulnerabilities::RiskScore.from_finding(finding).score
            }
          end

          next unless risk_scores.any?

          Vulnerabilities::FindingRiskScore.upsert_all(
            risk_scores,
            unique_by: :finding_id,
            update_only: [:risk_score]
          )

          log_updates
        end
      end

      private

      def filter_findings_by_feature_flag(findings)
        associations = [project: [:namespace]]
        ActiveRecord::Associations::Preloader.new(
          records: findings,
          associations: associations
        ).call

        findings_by_namespace = findings.group_by { |finding| finding.project.namespace_id }

        valid_findings = []
        findings_by_namespace.each_value do |findings|
          namespace = findings.first&.project&.namespace
          valid_findings += findings if ::Feature.enabled?(:vulnerability_finding_risk_score, namespace)
        end

        valid_findings
      end

      def timestamp
        @timestamp ||= Time.current
      end

      def log_updates
        Gitlab::AppLogger.info(
          class: self.class.name,
          message: "Vulnerability finding risk scores updated",
          vulnerability_ids: @vulnerability_ids,
          timestamp: timestamp
        )
      end
    end
  end
end
