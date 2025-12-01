# frozen_string_literal: true

module WorkItems
  module SystemDefined
    module Types
      module KeyResult
        WIDGETS = %w[
          assignees
          award_emoji
          current_user_todos
          custom_fields
          description
          health_status
          hierarchy
          labels
          linked_items
          notes
          notifications
          participants
          start_and_due_date
          progress
        ].freeze

        WIDGET_OPTIONS = {}.freeze

        def self.configuration
          {
            id: 7,
            name: 'Key Result',
            base_type: 'key_result',
            icon_name: "work-item-keyresult"
          }
        end

        def self.licence_name
          :okrs
        end
      end
    end
  end
end
