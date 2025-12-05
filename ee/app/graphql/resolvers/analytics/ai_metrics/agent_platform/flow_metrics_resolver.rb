# frozen_string_literal: true

module Resolvers
  module Analytics
    module AiMetrics
      module AgentPlatform
        class FlowMetricsResolver < BaseResolver
          include LooksAhead

          type [::Types::Analytics::AiMetrics::AgentPlatform::FlowMetricsType], null: true

          def resolve_with_lookahead
            flow_metrics = ::Analytics::AiAnalytics::AgentPlatform::FlowMetricsService.new(
              current_user,
              namespace: context[:ai_metrics_namespace],
              from: context[:ai_metrics_params][:start_date],
              to: context[:ai_metrics_params][:end_date],
              fields: lookahead.selections.map(&:name)
            ).execute

            flow_metrics.payload
          end
        end
      end
    end
  end
end
