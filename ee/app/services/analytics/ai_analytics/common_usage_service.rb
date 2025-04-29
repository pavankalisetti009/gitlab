# frozen_string_literal: true

module Analytics
  module AiAnalytics
    module CommonUsageService
      include Gitlab::Utils::StrongMemoize

      def initialize(current_user, namespace:, from:, to:, fields: nil)
        @current_user = current_user
        @namespace = namespace
        @from = from
        @to = to
        @fields = (fields & self.class::FIELDS) || self.class::FIELDS
      end

      def execute
        return feature_unavailable_error unless Gitlab::ClickHouse.enabled_for_analytics?(namespace)
        return ServiceResponse.success(payload: {}) unless fields.present?

        ServiceResponse.success(payload: usage_data.symbolize_keys!)
      end

      private

      attr_reader :current_user, :namespace, :from, :to, :fields

      def fetch_contributions_from_new_table?
        Feature.enabled?(:fetch_contributions_data_from_new_tables, namespace)
      end
      strong_memoize_attr :fetch_contributions_from_new_table?

      def feature_unavailable_error
        ServiceResponse.error(
          message: s_('AiAnalytics|the ClickHouse data store is not available')
        )
      end

      def placeholders
        {
          traversal_path: namespace.traversal_path(with_organization: fetch_contributions_from_new_table?),
          from: from.to_date.iso8601,
          to: to.to_date.iso8601
        }
      end

      def usage_data
        query = ClickHouse::Client::Query.new(raw_query: raw_query, placeholders: placeholders)
        ClickHouse::Client.select(query, :main).first
      end

      def raw_query
        raw_fields = fields.map do |field|
          "(#{self.class::FIELDS_SUBQUERIES[field]}) as #{field}"
        end.join(',')

        format(base_query, fields: raw_fields)
      end

      def base_query
        if fetch_contributions_from_new_table?
          self.class::QUERY.gsub('"contributions"', '"contributions_new"')
        else
          self.class::QUERY
        end
      end
    end
  end
end
