# frozen_string_literal: true

module WorkItems
  module Widgets
    module Statuses
      class UpdateService
        include Gitlab::InternalEventsTracking

        def initialize(work_item, current_user, status)
          @work_item = ensure_work_item(work_item)
          @current_user = current_user
          @status = status
        end

        def execute
          return unless has_correct_type?
          return if work_item.current_status&.status == status

          update_work_item_status
          create_system_note

          track_internal_event(
            'change_work_item_status_value',
            namespace: work_item.project&.namespace || work_item.namespace,
            project: work_item.project,
            user: current_user,
            additional_properties: {
              label: status.category.to_s
            }
          )
        end

        private

        attr_reader :work_item, :current_user, :status

        def has_correct_type?
          status && lifecycle.has_status_id?(status.id)
        end

        def lifecycle
          @lifecycle ||= work_item.work_item_type.status_lifecycle_for(root_ancestor)
        end

        def update_work_item_status
          current_status = work_item.current_status || work_item.build_current_status
          current_status.status = status

          current_status.save!
        end

        def create_system_note
          return unless work_item.current_status.previous_changes.key?(:custom_status_id) ||
            work_item.current_status.previous_changes.key?(:system_defined_status_id)

          ::SystemNotes::IssuablesService.new(
            noteable: work_item,
            container: work_item.namespace,
            author: current_user
          ).change_work_item_status(work_item.current_status.status)
        end

        def root_ancestor
          work_item.resource_parent&.root_ancestor
        end

        def ensure_work_item(work_item)
          return work_item if work_item.is_a?(WorkItem)

          WorkItem.find_by_id(work_item) if work_item.is_a?(Issue)
        end
      end
    end
  end
end
