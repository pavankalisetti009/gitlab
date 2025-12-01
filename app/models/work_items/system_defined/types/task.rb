# frozen_string_literal: true

module WorkItems
  module SystemDefined
    module Types
      module Task
        WIDGETS = %w[
          assignees
          award_emoji
          crm_contacts
          current_user_todos
          custom_fields
          description
          development
          hierarchy
          iteration
          labels
          linked_items
          linked_resources
          milestone
          notes
          notifications
          participants
          start_and_due_date
          time_tracking
          weight
          status
        ].freeze

        WIDGET_OPTIONS = {
          weight: { editable: true, rollup: false }
        }.freeze

        def self.configuration
          {
            id: 5,
            name: 'Task',
            base_type: 'task',
            icon_name: "work-item-task"
          }
        end
      end
    end
  end
end
