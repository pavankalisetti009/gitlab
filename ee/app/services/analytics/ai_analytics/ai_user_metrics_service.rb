# frozen_string_literal: true

module Analytics
  module AiAnalytics
    class AiUserMetricsService
      # rubocop: disable CodeReuse/ActiveRecord -- no ActiveRecord
      def initialize(current_user:, namespace:, from:, to:, user_ids:, feature:)
        @namespace = namespace
        @from = from
        @to = to
        @user_ids = user_ids
        @feature = feature
        @current_user = current_user
      end

      def execute
        return clickhouse_unavailable_error unless Gitlab::ClickHouse.enabled_for_analytics?(namespace)
        return ServiceResponse.success(payload: {}) unless feature_events.present?

        user_metrics = query_and_aggregate_metrics
        ServiceResponse.success(payload: user_metrics)
      end

      private

      attr_reader :current_user, :namespace, :from, :to, :user_ids, :feature

      def query_and_aggregate_metrics
        query = build_clickhouse_query
        raw_results = ClickHouse::Client.select(query, :main)

        aggregate_metrics_by_user(raw_results)
      end

      def aggregate_metrics_by_user(raw_results)
        user_metrics = {}

        raw_results.each do |row|
          user_id = row['user_id']
          event_name = event_name_from_id(row['event'])

          user_metrics[user_id] ||= {}
          user_metrics[user_id][:"#{event_name}_event_count"] = row['count']
        end

        user_metrics
      end

      def build_clickhouse_query
        builder = ClickHouse::Client::QueryBuilder.new('ai_usage_events_daily')

        query = builder
          .select(builder.table[:user_id], builder.table[:event], sum_occurrences_aggregate)

        query = date_range_condition(query, builder)
                  .group(:user_id, :event)
                  .order(:event, :asc)
        query = filter_by_feature(query, builder)
        apply_optional_filters(query, builder)
      end

      def apply_optional_filters(query, builder)
        query = filter_by_users(query, builder) if user_ids&.any?
        query = filter_by_namespace(query, builder) if namespace_filtering_enabled?
        query
      end

      def date_range_condition(query, builder)
        formatted_from = from.to_date.iso8601
        formatted_to = to.to_date.iso8601

        query.where(builder.table[:date].gteq(formatted_from))
             .where(builder.table[:date].lteq(formatted_to))
      end

      def filter_by_users(query, builder)
        query.where(builder.table[:user_id].in(user_ids))
      end

      def filter_by_feature(query, builder)
        event_ids = feature_event_ids
        query.where(builder.table[:event].in(event_ids))
      end

      def feature_events
        @feature_events ||= ::Gitlab::Tracking::AiTracking.registered_events(feature).keys
      end

      def feature_event_ids
        @feature_event_ids ||= feature_events.filter_map { |name| ::Ai::UsageEvent.events[name] }.compact
      end

      def filter_by_namespace(query, builder)
        namespace_path_condition = Arel::Nodes::NamedFunction.new('startsWith', [
          builder.table[:namespace_path],
          Arel::Nodes.build_quoted(namespace.traversal_path.to_s)
        ])

        query.where(namespace_path_condition)
      end

      def sum_occurrences_aggregate
        @sum_occurrences_aggregate ||= Arel::Nodes::NamedFunction.new('SUM', [Arel.sql('occurrences')]).as('count')
      end

      def event_name_from_id(event_id)
        ::Ai::UsageEvent.events.key(event_id)
      end

      def namespace_filtering_enabled?
        # for old Duo Chat we don't use namespace filtering for now. See https://gitlab.com/gitlab-org/gitlab/-/issues/578538
        Feature.enabled?(:use_ai_events_namespace_path_filter, namespace)
      end

      def clickhouse_unavailable_error
        ServiceResponse.error(
          message: s_('AiAnalytics|the ClickHouse data store is not available')
        )
      end
      # rubocop: enable CodeReuse/ActiveRecord
    end
  end
end
