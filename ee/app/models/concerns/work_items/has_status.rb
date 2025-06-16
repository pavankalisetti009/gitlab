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
          relation = relation.where(work_item_current_statuses: { custom_status_id: status.id })

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
                     .where(work_item_current_statuses: { system_defined_status_id: status.id })

        lifecycle = WorkItems::Statuses::SystemDefined::Lifecycle.all.first

        case status.id
        when lifecycle.default_open_status_id
          relation = relation.or(opened.without_current_status)
        when lifecycle.default_duplicate_status_id
          relation = relation.or(closed.without_current_status.where.not(duplicated_to_id: nil))
        when lifecycle.default_closed_status_id
          relation = relation.or(closed.without_current_status.where(duplicated_to_id: nil))
        end

        relation
      }

      scope :without_current_status, -> { left_joins(:current_status).where(work_item_current_statuses: { id: nil }) }

      def status_with_fallback
        if current_status.nil?
          lifecycle = work_item_type.system_defined_lifecycle

          return unless lifecycle

          default_status = if open?
                             lifecycle.default_open_status
                           elsif duplicated?
                             lifecycle.default_duplicate_status
                           else
                             lifecycle.default_closed_status
                           end

          build_current_status(system_defined_status: default_status)
        end

        current_status.status
      end
    end
  end
end
