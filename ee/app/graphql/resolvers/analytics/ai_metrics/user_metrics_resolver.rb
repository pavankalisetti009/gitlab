# frozen_string_literal: true

module Resolvers
  module Analytics
    module AiMetrics
      class UserMetricsResolver < BaseResolver
        include Gitlab::Graphql::Authorize::AuthorizeResource

        type ::Types::Analytics::AiMetrics::UserMetricsType, null: true

        authorizes_object!
        authorize :read_enterprise_ai_analytics

        ALL_FEATURES = ::Analytics::AiAnalytics::AiUserMetricsService::ALL_FEATURES

        argument :start_date, Types::DateType,
          required: false,
          description: 'Date range to start from. Default is the beginning of current month.
           ClickHouse needs to be enabled when passing this param.'

        argument :end_date, Types::DateType,
          required: false,
          description: 'Date range to end at. Default is the end of current month.
           ClickHouse needs to be enabled when passing this param.'

        argument :sort, Types::Analytics::AiMetrics::UserMetricsSortEnum,
          required: false,
          description: 'Sort AI user metrics.'

        def ready?(**args)
          validate_params!(args)

          super
        end

        def resolve(**args)
          context[:ai_metrics_params] = params_with_defaults(args).merge(namespace: namespace)

          assigned_users = fetch_assigned_users(args)

          return assigned_users if context[:ai_metrics_params][:sort].nil?

          sorted_user_ids = fetch_sorted_user_ids(assigned_users, context[:ai_metrics_params])

          sort_users_by_ids(assigned_users, sorted_user_ids)
        end

        private

        def fetch_assigned_users(args)
          ::GitlabSubscriptions::AddOnAssignedUsersFinder.new(
            current_user,
            namespace,
            add_on_name: :duo_enterprise,
            after: args[:start_date],
            before: args[:end_date]
          ).execute
        end

        def fetch_sorted_user_ids(users, params)
          # We need to perform an external query to sort users because the metrics are aggregated
          # The ai_metrics_service returns pre-sorted user IDs based on the requested metric,
          # which we then use to order the user records while preserving the sort order.

          result = ai_metrics_service(users.map(&:id), params).execute
          result.payload.keys
        end

        def ai_metrics_service(user_ids, params)
          ::Analytics::AiAnalytics::AiUserMetricsService.new(
            current_user: current_user,
            user_ids: user_ids,
            namespace: namespace,
            from: params[:start_date],
            to: params[:end_date],
            feature: first_registered_feature, # feature type doesn't matter for sorting
            sort: params[:sort]
          )
        end

        def first_registered_feature
          sort_field = context[:ai_metrics_params][:sort][:field]

          return ALL_FEATURES if total_events_sort?(sort_field)

          Gitlab::Tracking::AiTracking.registered_features.first
        end

        def total_events_sort?(sort_field)
          sort_field == :total_events_count
        end

        def sort_users_by_ids(users, sorted_ids)
          user_lookup = users.index_by(&:id)
          sorted_ids.filter_map { |user_id| user_lookup[user_id] }
        end

        def validate_params!(args)
          params = params_with_defaults(args)

          return unless params[:start_date] < params[:end_date] - 1.year

          raise Gitlab::Graphql::Errors::ArgumentError, 'maximum date range is 1 year'
        end

        def params_with_defaults(args)
          { start_date: Time.current.beginning_of_month, end_date: Time.current.end_of_month }.merge(args)
        end

        def namespace
          object.try(:project_namespace) || object
        end
      end
    end
  end
end
