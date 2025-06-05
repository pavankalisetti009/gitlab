# frozen_string_literal: true

module WorkItems
  module HasStatus
    extend ActiveSupport::Concern

    included do
      has_one :current_status, class_name: 'WorkItems::Statuses::CurrentStatus',
        foreign_key: 'work_item_id', inverse_of: :work_item

      scope :with_status, ->(status) {
        current_status_attrs = if status.is_a?(::WorkItems::Statuses::SystemDefined::Status)
                                 { system_defined_status_id: status.id }
                               else
                                 { custom_status_id: status.id }
                               end

        joins(:current_status).where(work_item_current_statuses: current_status_attrs)
      }

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
