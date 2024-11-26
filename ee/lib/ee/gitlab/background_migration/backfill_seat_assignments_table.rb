# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillSeatAssignmentsTable
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :backfill_subscription_seat_assignments
        end

        class MigrationSeatAssignmentTable < ::ApplicationRecord
          self.table_name = 'subscription_seat_assignments'
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            candidates_records = fetch_candidate_records(connection, sub_batch)

            next if candidates_records.empty?

            existing_records = fetch_existing_records(connection, candidates_records)
            non_existing_results = candidates_records.reject { |row| existing_records.include?(row) }

            next if non_existing_results.empty?

            current_time = Time.current
            attributes = non_existing_results.map do |row|
              {
                namespace_id: row['root_namespace_id'],
                user_id: row['user_id'],
                created_at: current_time,
                updated_at: current_time
              }
            end

            MigrationSeatAssignmentTable.insert_all(
              attributes,
              unique_by: [:namespace_id, :user_id]
            )
          end
        end

        private

        def fetch_candidate_records(connection, sub_batch)
          sql = <<~SQL
            SELECT DISTINCT
            user_id,
              (SELECT traversal_ids[1] FROM namespaces WHERE id = members.member_namespace_id)
            as root_namespace_id
            FROM members
            WHERE id IN (#{sub_batch.where.not(user_id: nil).select(:id).to_sql})
          SQL

          connection.exec_query(sql)
        end

        def fetch_existing_records(connection, records)
          tuples = Arel::Nodes::ValuesList.new(records.map { |row| [row['root_namespace_id'], row['user_id']] }).to_sql

          sql = <<~SQL
            SELECT namespace_id as root_namespace_id, user_id
            FROM
            subscription_seat_assignments
            WHERE (namespace_id, user_id) IN (#{tuples})
          SQL

          connection.exec_query(sql).to_a
        end
      end
    end
  end
end
