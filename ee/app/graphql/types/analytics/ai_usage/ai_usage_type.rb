# frozen_string_literal: true

module Types
  module Analytics
    module AiUsage
      class AiUsageType < BaseObject
        graphql_name 'AiUsage'
        description "Usage metrics. Not for production use yet."
        authorize :read_pro_ai_analytics

        extend ::Gitlab::Database::Aggregation::Graphql::Mounter

        mount_aggregation_engine ::Analytics::AggregationEngines::AgentPlatformSessions,
          field_name: :agent_platform_sessions,
          description: 'Aggregation engine for GitLab agent platform sessions usage' do
          define_method(:aggregation_scope) do
            engine_class.prepare_base_aggregation_scope(object)
          end
        end
      end
    end
  end
end
