# frozen_string_literal: true

module WorkItems
  module Callbacks
    class Status < Base
      def after_initialize
        return unless params.key?(:status)
        return if excluded_in_new_type?
        return unless feature_available?
        return unless has_permission?(:update_work_item)

        target_status = params[:status]
        return unless has_correct_type?(target_status)
        return if work_item.current_status&.status == target_status

        current_status = work_item.current_status || work_item.build_current_status
        current_status.status = target_status

        # Validation checks whether status is allowed for the lifecycle of the work item type.
        if current_status.valid?(:status_callback)
          work_item.current_status = current_status
        else
          raise_error(current_status.errors.full_messages.join(', '))
        end
      end

      def after_save
        return unless work_item.current_status&.previous_changes&.include?('system_defined_status_id')

        ::SystemNotes::IssuablesService.new(
          noteable: work_item,
          container: work_item.namespace,
          author: current_user
        ).change_work_item_status(work_item.current_status.status)
      end

      private

      def feature_available?
        work_item.resource_parent.try(:work_item_status_feature_available?)
      end

      def has_correct_type?(status)
        status.is_a?(::WorkItems::Statuses::SystemDefined::Status)
      end
    end
  end
end
