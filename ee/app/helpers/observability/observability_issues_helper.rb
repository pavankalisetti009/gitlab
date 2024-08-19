# frozen_string_literal: true

module Observability
  module ObservabilityIssuesHelper
    include ::Observability::MetricsIssuesHelper
    include ::Observability::LogsIssuesHelper

    def observability_issue_params
      return {} unless can?(current_user, :read_observability, container)

      links_params = parsed_link_params(params[:observability_links])

      if links_params[:metrics].present?
        observability_metrics_issues_params(links_params[:metrics])
      elsif links_params[:logs].present?
        observability_logs_issues_params(links_params[:logs])
      else
        {}
      end
    end

    private

    def parsed_link_params(links_params)
      return {} unless links_params.present?

      {
        metrics: safe_parse_json(links_params[:metrics]),
        logs: safe_parse_json(links_params[:logs])
      }
    end

    def safe_parse_json(stringified_json)
      return {} if stringified_json.blank?

      ::Gitlab::Json.parse(CGI.unescape(stringified_json))
    rescue JSON::ParserError, TypeError
      {}
    end
  end
end
