# frozen_string_literal: true

module Analytics
  module AiAnalytics
    class AiUserMetricsService
      ALL_FEATURES = :all_features

      # rubocop: disable CodeReuse/ActiveRecord -- no ActiveRecord
      def initialize(current_user:, namespace:, from:, to:, user_ids:, feature:, sort: nil)
        @namespace = namespace
        @from = from
        @to = to
        @user_ids = user_ids
        @feature = feature
        @sort = sort
        @current_user = current_user
      end

      def execute
        return clickhouse_unavailable_error unless Gitlab::ClickHouse.enabled_for_analytics?(namespace)
        return ServiceResponse.success(payload: {}) unless feature_events.present?

        user_metrics = query_and_aggregate_metrics

        ServiceResponse.success(payload: user_metrics)
      end

      private

      attr_reader :current_user, :namespace, :from, :to, :user_ids, :feature, :sort

      def fetch_all_features?
        feature == ALL_FEATURES
      end

      def query_and_aggregate_metrics
        builder = ClickHouse::Client::QueryBuilder.new('ai_usage_events_daily')
        query = build_unified_query(builder)
        raw_results = ClickHouse::Client.select(query, :main)

        raw_results.each_with_object({}) do |row, hash|
          user_id = row['user_id']

          user_metrics = row.except('user_id').transform_keys(&:to_sym)
          hash[user_id] = user_metrics
        end
      end

      def build_unified_query(builder)
        query = builder
          .select(builder.table[:user_id])
          .then { |q| add_total_events_count(q, builder) }
          .then { |q| add_event_aggregations(q, builder) }
          .then { |q| apply_common_filters(q, builder, user_ids: user_ids) }
          .group(:user_id)

        query = apply_sorting(query, builder) if sort.present?
        query
      end

      def add_total_events_count(query, builder)
        total_count_expression = Arel::Nodes::NamedFunction.new('sumIf', [
          Arel.sql('occurrences'),
          builder.table[:event].in(feature_event_ids)
        ]).as('total_events_count')

        query.select(total_count_expression)
      end

      def add_event_aggregations(query, builder)
        feature_event_ids.each do |event_id|
          event_name = event_name_from_id(event_id)
          count_expression = Arel::Nodes::NamedFunction.new('sumIf', [
            Arel.sql('occurrences'),
            builder.table[:event].eq(event_id)
          ]).as("#{event_name}_event_count")

          query = query.select(count_expression)
        end

        last_activity_expression = Arel::Nodes::NamedFunction.new('nullIf', [
          Arel::Nodes::NamedFunction.new('maxIf', [
            builder.table[:date],
            builder.table[:event].in(feature_event_ids)
          ]),
          Arel.sql("toDate32('1970-01-01')")
        ]).as('last_duo_activity_on')

        query.select(last_activity_expression)
      end

      def apply_sorting(query, builder)
        sort_field = sort[:field]
        direction = sort[:direction]

        if sort_field == :total_events_count
          # Sort by count of all events of all features
          query.order(Arel.sql('total_events_count'), direction)
        elsif ::Ai::UsageEvent.events[sort_field].present?
          # Sort by a specific event within the feature
          event_id = ::Ai::UsageEvent.events[sort_field]

          sort_expression = Arel::Nodes::NamedFunction.new('sumIf', [
            Arel.sql('occurrences'),
            builder.table[:event].eq(event_id)
          ])
          query.order(sort_expression, direction)
        else
          # Sort by count of all events of a specific feature
          sort_event_ids = event_ids_for_feature(sort_field)
          sort_expression = Arel::Nodes::NamedFunction.new('sumIf', [
            Arel.sql('occurrences'),
            builder.table[:event].in(sort_event_ids)
          ])
          query.order(sort_expression, direction)
        end
      end

      def apply_common_filters(query, builder, user_ids:)
        query = date_range_condition(query, builder)
        apply_optional_filters(query, builder, user_ids: user_ids)
      end

      def apply_optional_filters(query, builder, user_ids:)
        query = query.where(builder.table[:user_id].in(user_ids)) if user_ids&.any?
        query = filter_by_namespace(query, builder) if namespace_filtering_enabled?
        query
      end

      def event_ids_for_feature(feature_name)
        return feature_event_ids if feature_name == feature

        ::Gitlab::Tracking::AiTracking.registered_events(feature_name).values
      end

      def date_range_condition(query, builder)
        formatted_from = from.to_date.iso8601
        formatted_to = to.to_date.iso8601

        query.where(builder.table[:date].gteq(formatted_from))
             .where(builder.table[:date].lteq(formatted_to))
      end

      def feature_events
        @feature_events ||= registered_event_names
      end

      def feature_event_ids
        @feature_event_ids ||= registered_event_names.filter_map do |name|
          ::Ai::UsageEvent.events[name]
        end.compact
      end

      def registered_event_names
        if fetch_all_features?
          Gitlab::Tracking::AiTracking.registered_features.flat_map do |feature|
            ::Gitlab::Tracking::AiTracking.registered_events(feature).keys
          end
        else
          ::Gitlab::Tracking::AiTracking.registered_events(feature).keys
        end
      end

      def filter_by_namespace(query, builder)
        namespace_path_condition = Arel::Nodes::NamedFunction.new('startsWith', [
          builder.table[:namespace_path],
          Arel::Nodes.build_quoted(namespace.traversal_path.to_s)
        ])

        query.where(namespace_path_condition)
      end

      def event_name_from_id(event_id)
        ::Ai::UsageEvent.events.key(event_id)
      end

      def namespace_filtering_enabled?
        return Feature.enabled?(:use_duo_chat_namespace_path_filter, namespace) if feature.to_sym == :chat

        true
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
