# frozen_string_literal: true

module WorkItems
  module HasStatus
    extend ActiveSupport::Concern

    included do
      has_one :current_status, class_name: 'WorkItems::Statuses::CurrentStatus',
        foreign_key: 'work_item_id', inverse_of: :work_item

      scope :with_status, ->(status) {
        relation = left_joins(:current_status)

        if status.is_a?(::WorkItems::Statuses::SystemDefined::Status)
          relation = with_system_defined_status(status)
        else
          relation = relation
            .where.not(work_item_current_statuses: { custom_status_id: nil })
            .where(work_item_current_statuses: { custom_status_id: status.id })

          if status.converted_from_system_defined_status_identifier.present?
            system_defined_status = WorkItems::Statuses::SystemDefined::Status.find(
              status.converted_from_system_defined_status_identifier
            )

            relation = relation.or(with_system_defined_status(system_defined_status))
          end
        end

        relation
      }

      scope :with_system_defined_status, ->(status) {
        next none unless status.is_a?(::WorkItems::Statuses::SystemDefined::Status)

        relation = left_joins(:current_status)
                    .where.not(work_item_current_statuses: { system_defined_status_id: nil })
                    .where(work_item_current_statuses: { system_defined_status_id: status.id })

        lifecycle = WorkItems::Statuses::SystemDefined::Lifecycle.all.first

        with_default_status = case status.id
                              when lifecycle.default_open_status_id
                                opened
                              when lifecycle.default_duplicate_status_id
                                closed.where.not(duplicated_to_id: nil)
                              when lifecycle.default_closed_status_id
                                closed.where(duplicated_to_id: nil)
                              end

        next relation if with_default_status.nil?

        relation.or(
          with_default_status.without_current_status.with_issue_type(lifecycle.work_item_base_types)
        )
      }

      scope :without_current_status, -> { left_joins(:current_status).where(work_item_current_statuses: { id: nil }) }

      scope :not_in_statuses, ->(statuses) {
        return all if statuses.blank?

        items_to_exclude = statuses.reduce(unscoped.none) do |relation, status|
          relation.or(with_status(status))
        end

        merge(items_to_exclude.invert_where)
      }

      scope :with_status_joins, -> {
        converted_statuses_join = <<-SQL.squish
          LEFT JOIN namespaces ON namespaces.id = #{table_name}.namespace_id
          LEFT JOIN work_item_custom_statuses converted_statuses ON
            converted_statuses.converted_from_system_defined_status_identifier =
              work_item_current_statuses.system_defined_status_id
            AND converted_statuses.namespace_id = namespaces.traversal_ids[1]
        SQL

        left_joins(current_status: :custom_status).joins(converted_statuses_join)
      }

      scope :order_status_asc, -> {
        with_status_joins.order(Arel.sql("#{generate_status_order_sql} ASC NULLS LAST, id DESC"))
      }

      scope :order_status_desc, -> {
        with_status_joins.order(Arel.sql("#{generate_status_order_sql} DESC NULLS FIRST, id DESC"))
      }

      def self.generate_status_order_sql
        system_defined_sort_orders = WorkItems::Statuses::SystemDefined::Status.sort_order_by_id
        system_defined_status_cases = system_defined_sort_orders.map do |id, category|
          "WHEN #{id} THEN #{category}"
        end.join(' ')

        lifecycle = WorkItems::Statuses::SystemDefined::Lifecycle.all.first
        default_open_status = lifecycle.default_open_status
        default_duplicate_status = lifecycle.default_duplicate_status
        default_closed_status = lifecycle.default_closed_status

        default_open_sort_order = system_defined_sort_orders[default_open_status.id]
        default_duplicate_sort_order = system_defined_sort_orders[default_duplicate_status.id]
        default_closed_sort_order = system_defined_sort_orders[default_closed_status.id]

        opened_state_value = Issue.available_states[:opened]
        closed_state_value = Issue.available_states[:closed]

        <<-SQL.squish
          CASE
            WHEN work_item_current_statuses.custom_status_id IS NOT NULL THEN
              work_item_custom_statuses.category
            WHEN work_item_current_statuses.system_defined_status_id IS NOT NULL THEN
              COALESCE(
                converted_statuses.category,
                CASE work_item_current_statuses.system_defined_status_id #{system_defined_status_cases} END
              )
            ELSE
              CASE
                WHEN #{table_name}.state_id = #{opened_state_value} THEN #{default_open_sort_order}
                WHEN #{table_name}.state_id = #{closed_state_value} AND #{table_name}.duplicated_to_id IS NOT NULL
                  THEN #{default_duplicate_sort_order}
                WHEN #{table_name}.state_id = #{closed_state_value} AND #{table_name}.duplicated_to_id IS NULL
                  THEN #{default_closed_sort_order}
                ELSE #{default_open_sort_order}
              END
          END
        SQL
      end

      def status_with_fallback
        current_status_with_fallback&.status
      end

      def current_status_with_fallback
        return current_status if current_status.present?

        lifecycle = work_item_type.system_defined_lifecycle
        return unless lifecycle

        build_current_status(system_defined_status: lifecycle.default_status_for_work_item(self))
      end
    end
  end
end
