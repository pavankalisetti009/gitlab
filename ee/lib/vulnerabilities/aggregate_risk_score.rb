# frozen_string_literal: true

module Vulnerabilities
  class AggregateRiskScore
    # Calculate aggregate risk score for scoped vulnerabilities
    # This can be for a group or a project or any set of vulnerabilities.
    # Risk Score = (Sum(Vulnerability Scores) + Sum(Vulnerability_age_in_month) x 0.005) / sqrt(num_vulnerabilities)
    #
    # Arguments -
    #
    #   risk_score_sum: sum of all vulnerability finding risk scores
    #   created_at_sum: sum of epoch values for created_at, in milliseconds
    #   active_vulnerabilities_count: number of active vulnerabilities
    def self.score(risk_scores_sum:, created_at_sum:, active_vulnerabilities_count:)
      return 0.0 if active_vulnerabilities_count == 0

      # division by 1000 because created_at_sum is in milli seconds where as Time.zone.now.to_f gives seconds
      date_diff = (active_vulnerabilities_count * Time.zone.now.to_f) - (created_at_sum / 1000)
      date_diff_in_months = date_diff / 86400 / 30

      age_factor = 0.005 * date_diff_in_months
      total_risk_score = ((risk_scores_sum + age_factor) / Math.sqrt(active_vulnerabilities_count)).round(4)

      [1.0, total_risk_score.to_f].min
    end
  end
end
