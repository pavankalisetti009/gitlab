# frozen_string_literal: true

module WorkItems
  module Callbacks
    class Status < Base
      include Gitlab::Utils::StrongMemoize

      ALLOWED_PARAMS = [:status].freeze

      def self.execute_without_params?
        true
      end

      def after_save
        return if excluded_in_new_type?
        return unless has_permission?(:update_work_item) || has_permission?(:update_issue)

        target_status = find_target_status

        update_current_status(target_status)
      end

      private

      def update_current_status(status)
        return unless status

        case status.state
        when :open
          if work_item.closed?
            Issues::ReopenService.new(container: work_item.namespace, current_user: current_user)
              .execute(work_item, status: status)
          else
            ::WorkItems::Widgets::Statuses::UpdateService.new(work_item, current_user, status).execute
          end
        when :closed
          if work_item.open?
            Issues::CloseService.new(container: work_item.namespace, current_user: current_user)
              .execute(work_item, status: status)
          else
            ::WorkItems::Widgets::Statuses::UpdateService.new(work_item, current_user, status).execute
          end
        end
      end

      def find_target_status
        return params[:status] if params[:status].present?

        # Ensure any supported item has a valid status upon creation
        lifecycle&.default_open_status unless work_item.current_status
      end

      def lifecycle
        work_item.work_item_type.status_lifecycle_for(root_ancestor)
      end
      strong_memoize_attr :lifecycle

      def root_ancestor
        work_item.resource_parent&.root_ancestor
      end
      strong_memoize_attr :root_ancestor
    end
  end
end
