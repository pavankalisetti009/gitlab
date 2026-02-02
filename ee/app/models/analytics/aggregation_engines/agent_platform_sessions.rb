# frozen_string_literal: true

module Analytics
  module AggregationEngines
    class AgentPlatformSessions < Gitlab::Database::Aggregation::ClickHouse::Engine
      self.table_name = 'agent_platform_sessions'
      self.table_primary_key = %w[user_id namespace_path session_id flow_type]

      dimensions do
        column :flow_type, :string, description: 'Type of session'
        column :user_id, :integer, description: 'Session owner', association: true
        date_bucket :created_event_at, :date, -> {
          sql('anyIfMerge(created_event_at)')
        }, description: 'Session creation time', parameters: {
          granularity: { type: :string, in: %w[weekly monthly] }
        }
      end

      metrics do
        count description: 'Total number of sessions'
        count :finished, if: -> {
          sql('anyIfMerge(finished_event_at) IS NOT NULL')
        }, description: 'Number of finished sessions'
        count :users, :integer, -> { sql('user_id') }, distinct: true, description: 'Number of unique users'

        mean :duration, :float, -> {
          sql("dateDiff('seconds', anyIfMerge(created_event_at), anyIfMerge(finished_event_at))")
        }, description: 'Average session duration in seconds'

        rate :completion, numerator_if: -> {
          sql('anyIfMerge(finished_event_at) IS NOT NULL')
        }, description: 'Session completion rate'

        quantile :duration, :float, -> {
          sql("dateDiff('seconds', anyIfMerge(created_event_at), anyIfMerge(finished_event_at))")
        }, description: 'Session duration quantile in seconds', parameters: {
          quantile: { type: :float, in: 0.0..1.0 }
        }
      end

      filters do
        exact_match :user_id, :integer, description: 'Filter by one or many user ids'
        exact_match :flow_type, :string, description: 'Filter by one or many flow types'
        range :created_event_at, :datetime, -> { sql('anyIfMerge(created_event_at)') },
          merge_column: true,
          description: 'Filter by session creation timestamp'
      end

      def self.prepare_base_aggregation_scope(object)
        namespace = case object
                    when Project then object.project_namespace
                    else object
                    end

        builder = ClickHouse::Client::QueryBuilder.new(table_name)

        builder.where(builder.func('startsWith', [
          builder[:namespace_path], Arel::Nodes.build_quoted(namespace.traversal_path.to_s)
        ]))
      end
    end
  end
end
