# frozen_string_literal: true

module Resolvers
  module Analytics
    module AiMetrics
      class CodeReviewMetricsResolver < BaseResolver
        include LooksAhead

        type ::Types::Analytics::AiMetrics::CodeReviewMetricsType, null: true

        def resolve_with_lookahead
          usage = ::Analytics::AiAnalytics::UsageEventCountService.new(
            current_user,
            namespace: context[:ai_metrics_namespace],
            from: context[:ai_metrics_params][:start_date],
            to: context[:ai_metrics_params][:end_date],
            fields: lookahead.selections.map(&:name)
          ).execute

          usage.payload
        end
      end
    end
  end
end
