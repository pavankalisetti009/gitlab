# frozen_string_literal: true

module Observability
  module MetricsIssuesHelper
    def observability_metrics_issues_params(params)
      return {} if params.blank?

      {
        title: "Issue created from #{params['name']}",
        description: observability_metrics_issue_description(params)
      }
    end

    private

    def observability_metrics_issue_description(params)
      <<~TEXT
        [Metric details](#{params['fullUrl']}) \\
        Name: `#{params['name']}` \\
        Type: `#{params['type']}` \\
        Timeframe: `#{params.dig('timeframe', 0)} - #{params.dig('timeframe', 1)}`
      TEXT
    end
  end
end
