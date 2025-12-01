# frozen_string_literal: true

module WorkItems
  module SystemDefined
    module Types
      module Epic
        WIDGETS = %w[
          assignees
          award_emoji
          color
          current_user_todos
          custom_fields
          description
          health_status
          hierarchy
          labels
          linked_items
          milestone
          notes
          notifications
          participants
          start_and_due_date
          verification_status
          time_tracking
          weight
        ].freeze

        WIDGET_OPTIONS = {
          weight: { editable: false, rollup: true }
        }.freeze

        def self.configuration
          {
            id: 8,
            name: 'Epic',
            base_type: 'epic',
            icon_name: "work-item-epic"
          }
        end

        def self.licence_name
          :epics
        end
      end
    end
  end
end
