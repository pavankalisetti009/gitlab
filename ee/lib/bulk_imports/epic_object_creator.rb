# frozen_string_literal: true

module BulkImports
  module EpicObjectCreator
    extend ActiveSupport::Concern

    included do
      def save_relation_object(relation_object, relation_key, relation_definition, relation_index)
        return super unless %w[epics epic issues issue].include?(relation_key)

        if %w[issues issue].include?(relation_key)
          super # create the issue first
          return handle_epic_issue(relation_object)
        end

        create_epic(relation_object) if relation_object.new_record?
      end

      def persist_relation(attributes)
        relation_object = super(**attributes)

        return relation_object if !relation_object || !relation_object.is_a?(::Epic) || relation_object.persisted?

        create_epic(relation_object)
      end

      private

      def create_epic(epic_object)
        # we need to handle epics slightly differently because Epics::CreateService accounts for creating the
        # respective epic work item as well as some other associations.
        ::WorkItems::LegacyEpics::Imports::CreateFromImportedEpicService.new(
          group: epic_object.group, current_user: current_user, epic_object: epic_object
        ).execute
      end

      def handle_epic_issue(issue)
        issue_as_work_item = WorkItem.id_in(issue.id).first

        if issue_as_work_item&.epic&.work_item
          existing_parent_link = issue_as_work_item.epic.work_item.child_links.for_children(issue_as_work_item)
          return if existing_parent_link.present?

          create_parent_link = ::WorkItems::ParentLinks::CreateService.new(
            issue_as_work_item.epic.work_item, current_user,
            { target_issuable: issue_as_work_item, synced_work_item: true }
          ).execute

          return unless create_parent_link[:status] == :success

          legacy_epic_issue_link = issue.epic_issue
          legacy_epic_issue_link.work_item_parent_link_id = create_parent_link[:created_references].first.id
          legacy_epic_issue_link.save(touch: false)
        end

        issue
      end
    end
  end
end
