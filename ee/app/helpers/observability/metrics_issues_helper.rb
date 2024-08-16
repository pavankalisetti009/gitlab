# frozen_string_literal: true

module Observability
  module MetricsIssuesHelper
    def observability_metric_issue_description(params)
      <<-TEXT
[Metric details](#{params['fullUrl']}) \\
Name: `#{params['name']}` \\
Type: `#{params['type']}` \\
Timeframe: `#{params.dig('timeframe', 0)} - #{params.dig('timeframe', 1)}`
      TEXT
    end

    def observability_issue_params
      return {} unless can?(current_user, :read_observability, container)

      begin
        links_params = ::Gitlab::Json.parse(CGI.unescape(params[:observability_links]))

        return {} if links_params.blank?

        {
          title: "Issue created from #{links_params['name']}",
          description: observability_metric_issue_description(links_params)
        }
      rescue JSON::ParserError, TypeError
        {}
      end
    end

    def process_observability_links(issue, links)
      ::Observability::MetricsIssuesConnection.create!(
        metric_name: links[:metric_details_name],
        metric_type: links[:metric_details_type],
        issue: issue
      )
    end
  end
end
