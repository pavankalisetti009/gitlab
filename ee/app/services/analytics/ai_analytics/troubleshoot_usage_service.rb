# frozen_string_literal: true

module Analytics
  module AiAnalytics
    class TroubleshootUsageService
      include CommonUsageService

      QUERY = <<~SQL
        SELECT COUNT(DISTINCT user_id) as root_cause_analysis_users_count
        FROM troubleshoot_job_events
        WHERE timestamp >= {from:Date}
        AND timestamp <= {to:Date}
      SQL

      FIELDS_SUBQUERIES = {
        root_cause_analysis_users_count: QUERY
      }.freeze

      FIELDS = FIELDS_SUBQUERIES.keys
    end
  end
end
