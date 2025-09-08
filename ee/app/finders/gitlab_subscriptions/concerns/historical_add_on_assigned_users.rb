# frozen_string_literal: true

module GitlabSubscriptions
  module Concerns
    module HistoricalAddOnAssignedUsers
      def historical_add_on_assigned_users
        unless ::Gitlab::ClickHouse.globally_enabled_for_analytics?
          raise ClickHouse::Errors::DisabledError.new(
            msg: 'ClickHouse is not enabled: Failed to fetch historical add-on assignments'
          )
        end

        User.by_ids(user_ids_with_active_assignments_in_period)
      end

      private

      attr_reader :namespace, :current_user, :add_on_name, :after, :before

      def user_ids_with_active_assignments_in_period
        actual_start_date = after || Time.at(0)
        actual_end_date = before || Time.now

        raw_query = <<~SQL
          WITH latest_assignment_state AS (
            SELECT
              user_id,
              namespace_path,
              add_on_name,
              MAX(assigned_at) as assigned_at,
              MAX(revoked_at) as revoked_at
            FROM user_add_on_assignments_history
            WHERE namespace_path = {root_namespace:String}
            AND add_on_name = {add_on_name:String}
            GROUP BY user_id, namespace_path, add_on_name
          )
          SELECT DISTINCT user_id as uid
          FROM latest_assignment_state
          WHERE assigned_at <= {end_date:Date}
            AND (revoked_at IS NULL OR revoked_at >= {start_date:Date})
        SQL

        query = ClickHouse::Client::Query.new(
          raw_query: raw_query,
          placeholders: {
            start_date: actual_start_date.to_date.iso8601,
            end_date: actual_end_date.to_date.iso8601,
            add_on_name: add_on_name.to_s,
            root_namespace: namespace&.root_ancestor&.traversal_path || '0/'
          }
        )

        ClickHouse::Client.select(query, :main).map { |record| record["uid"] } # rubocop:disable Rails/Pluck -- ClickHouse result is not an ActiveRecord relation
      end
    end
  end
end
