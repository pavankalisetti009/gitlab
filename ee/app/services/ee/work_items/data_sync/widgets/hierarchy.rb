# frozen_string_literal: true

module EE
  module WorkItems
    module DataSync
      module Widgets
        module Hierarchy
          extend ::Gitlab::Utils::Override

          BATCH_SIZE = ::WorkItems::DataSync::Widgets::Base::BATCH_SIZE

          private

          override :relink_children_to_target_work_item
          def relink_children_to_target_work_item
            super

            # Every Epic Work Item has to have a legacy Epic record.
            source_legacy_epic = work_item.sync_object
            target_legacy_epic = target_work_item.sync_object
            return unless source_legacy_epic && target_legacy_epic

            # We need to handle legacy Epic children records upon Epic Work Item move.
            # Since we move legacy Epic to Work Item we will just "relink" child items to the new
            # parent legacy Epic.
            #
            # This will be removed once we remove legacy Epic dependencies,
            # see: https://gitlab.com/groups/gitlab-org/-/epics/13356
            epic_type = ::WorkItems::Type.default_by_type(:epic)
            return unless epic_type.id == work_item.work_item_type.id

            # handling child epics
            source_legacy_epic.children.each_batch(of: BATCH_SIZE) do |children|
              # we do not need to update `epics.work_item_parent_link_id`, because in
              # `super.relink_children_to_target_work_item` we did not create a new WorkItems::ParentLink record
              # we just changed the `work_item_parent_id` on the new target work item record.
              children.update_all(parent_id: target_legacy_epic.id)
            end

            # handling child issues
            source_legacy_epic.epic_issues.each_batch(of: BATCH_SIZE, column: :issue_id) do |epic_issue|
              # we do not need to update `epics.work_item_parent_link_id`, because in
              # `super.relink_children_to_target_work_item` we did not create a new `WorkItems::ParentLink` record
              # we just changed the `work_item_parent_id` on the new target work item record.
              epic_issue.update_all(epic_id: target_legacy_epic.id)
            end
          end
        end
      end
    end
  end
end
