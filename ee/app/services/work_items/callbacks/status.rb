# frozen_string_literal: true

module WorkItems
  module Callbacks
    class Status < Base
      def after_save
        return unless params.key?(:status)
        return if excluded_in_new_type?
        return unless feature_available?
        return unless has_permission?(:update_work_item)

        target_status = params[:status]
        return unless has_correct_type?(target_status)
        return if work_item.current_status&.status == target_status

        update_work_item_status(target_status)
        create_system_note
      end

      private

      def feature_available?
        work_item.resource_parent.try(:work_item_status_feature_available?)
      end

      # TODO: Handle custom statuses
      # https://gitlab.com/gitlab-org/gitlab/-/work_items/524078
      def has_correct_type?(status)
        status.is_a?(::WorkItems::Statuses::SystemDefined::Status)
      end

      def update_work_item_status(target_status)
        current_status = work_item.current_status || work_item.build_current_status
        current_status.status = target_status

        current_status.save!
      end

      # TODO: Handle custom statuses
      # https://gitlab.com/gitlab-org/gitlab/-/work_items/524078
      def create_system_note
        return unless work_item.current_status&.system_defined_status_id_previously_changed?

        ::SystemNotes::IssuablesService.new(
          noteable: work_item,
          container: work_item.namespace,
          author: current_user
        ).change_work_item_status(work_item.current_status.status)
      end
    end
  end
end
