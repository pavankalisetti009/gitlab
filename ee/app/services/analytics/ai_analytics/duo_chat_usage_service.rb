# frozen_string_literal: true

module Analytics
  module AiAnalytics
    class DuoChatUsageService
      QUERY = <<~SQL
        -- cte to load code contributors
        WITH contributors AS (
          SELECT DISTINCT author_id
          FROM contributions
          WHERE startsWith(path, {traversal_path:String})
          AND "contributions"."created_at" >= {from:Date}
          AND "contributions"."created_at" <= {to:Date}
        )
        SELECT %{fields}
      SQL
      private_constant :QUERY

      CONTRIBUTORS_COUNT_QUERY = "SELECT count(*) FROM contributors"
      private_constant :CONTRIBUTORS_COUNT_QUERY

      DUO_CHAT_CONTRIBUTORS_COUNT_QUERY = <<~SQL
        SELECT COUNT(DISTINCT user_id)
          FROM duo_chat_daily_events
          WHERE user_id IN (SELECT author_id FROM contributors)
          AND date >= {from:Date}
          AND date <= {to:Date}
          AND event = 1
      SQL
      private_constant :DUO_CHAT_CONTRIBUTORS_COUNT_QUERY

      FIELDS_SUBQUERIES = {
        contributors_count: CONTRIBUTORS_COUNT_QUERY,
        duo_chat_contributors_count: DUO_CHAT_CONTRIBUTORS_COUNT_QUERY
      }.freeze
      private_constant :FIELDS_SUBQUERIES

      FIELDS = FIELDS_SUBQUERIES.keys

      def initialize(current_user, namespace:, from:, to:, fields: FIELDS)
        @current_user = current_user
        @namespace = namespace
        @from = from
        @to = to
        @fields = fields
      end

      def execute
        return feature_unavailable_error unless Gitlab::ClickHouse.enabled_for_analytics?(namespace)

        return ServiceResponse.success(payload: {}) unless fields.present?

        ServiceResponse.success(payload: usage_data.symbolize_keys!)
      end

      private

      attr_reader :current_user, :namespace, :from, :to, :fields

      def feature_unavailable_error
        ServiceResponse.error(
          message: s_('AiAnalytics|the ClickHouse data store is not available')
        )
      end

      def usage_data
        query = ClickHouse::Client::Query.new(raw_query: raw_query, placeholders: placeholders)
        ClickHouse::Client.select(query, :main).first
      end

      def raw_query
        raw_fields = fields.map do |field|
          "(#{FIELDS_SUBQUERIES[field]}) as #{field}"
        end.join(',')

        format(QUERY, fields: raw_fields)
      end

      def placeholders
        {
          traversal_path: namespace.traversal_path,
          from: from.to_date.iso8601,
          to: to.to_date.iso8601
        }
      end
    end
  end
end
