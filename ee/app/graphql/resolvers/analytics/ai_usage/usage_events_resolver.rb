# frozen_string_literal: true

module Resolvers
  module Analytics
    module AiUsage
      class UsageEventsResolver < BaseResolver
        type ::Types::Analytics::AiUsage::AiUsageEventType.connection_type, null: true

        argument :start_date, Types::DateType,
          required: false,
          description: 'Date range to start from. Default is 7 days ago.'

        argument :end_date, Types::DateType,
          required: false,
          description: 'Date range to end at. Default is the end of current day.'

        def ready?(**args)
          check_feature_availability!
          validate_params!(args)

          super
        end

        def resolve(**args)
          params = params_with_defaults(args)

          ::Ai::UsageEventsFinder.new(current_user,
            resource: namespace,
            from: params[:start_date],
            to: params[:end_date]).execute
        end

        private

        def validate_params!(args)
          params = params_with_defaults(args)

          return if params[:start_date] > params[:end_date] - 1.month

          raise Gitlab::Graphql::Errors::ArgumentError, 'maximum date range is 1 month'
        end

        def check_feature_availability!
          return if Feature.enabled?(:unified_ai_events_graphql, object)

          raise Gitlab::Graphql::Errors::ArgumentError, 'Not available for this resource.'
        end

        def namespace
          object.is_a?(Namespace) ? object : object.project_namespace
        end

        def params_with_defaults(args)
          { start_date: 7.days.ago.beginning_of_day, end_date: Time.current.end_of_day }.merge(args)
        end
      end
    end
  end
end
