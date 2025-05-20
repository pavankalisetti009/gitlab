# frozen_string_literal: true

module WorkItems
  module Callbacks
    class Status < Base
      ALLOWED_PARAMS = [:status].freeze

      def self.execute_without_params?
        true
      end

      def after_save
        return if excluded_in_new_type?
        return unless has_permission?(:update_work_item) || has_permission?(:update_issue)

        target_status = find_target_status

        return if work_item.current_status&.status == target_status

        update_work_item_status(target_status)
        create_system_note
      end

      private

      def find_target_status
        return params[:status] if params[:status].present? && feature_available? && has_correct_type?(params[:status])
        return unless transitions_enabled?

        # Ensure any supported item has a valid status upon creation
        default_open_status unless work_item.current_status
      end

      # TODO: Handle custom statuses
      # https://gitlab.com/gitlab-org/gitlab/-/work_items/524078
      def default_open_status
        # Only returns a default open status if there's a lifecycle attached to this type
        ::WorkItems::Statuses::SystemDefined::Lifecycle
          .of_work_item_base_type(work_item.work_item_type.base_type)
          &.default_open_status
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

      def feature_available?
        root_ancestor&.try(:work_item_status_feature_available?)
      end

      # Short-lived feature flag to guard adding current_status rows for each supported type
      def transitions_enabled?
        root_ancestor&.try(:work_item_status_transitions_enabled?)
      end

      def root_ancestor
        work_item.resource_parent&.root_ancestor
      end

      # TODO: Handle custom statuses
      # https://gitlab.com/gitlab-org/gitlab/-/work_items/524078
      def create_system_note
        return unless feature_available?
        # Status cannot be updated intentionally by the user from any of the issue services.
        # It's only supported by the new work item services,
        # so we can skip note creation if it's a legacy issue object
        return if work_item.instance_of?(Issue)
        return unless work_item.get_widget(:status)
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
