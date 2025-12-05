# frozen_string_literal: true

module Types
  module Analytics
    module AiMetrics
      # rubocop: disable Graphql/AuthorizeTypes -- authorized by parent type
      class AgentPlatformMetricsType < BaseObject
        graphql_name 'agentPlatformMetrics'
        description 'Requires ClickHouse. Premium and Ultimate only.'

        field :flow_metrics,
          null: true,
          description: 'Aggregated flow metrics for agent platform.',
          resolver: Resolvers::Analytics::AiMetrics::AgentPlatform::FlowMetricsResolver
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
