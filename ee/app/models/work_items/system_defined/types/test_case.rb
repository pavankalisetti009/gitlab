# frozen_string_literal: true

module WorkItems
  module SystemDefined
    module Types
      module TestCase
        WIDGETS = %w[
          award_emoji
          current_user_todos
          custom_fields
          description
          linked_items
          notes
          notifications
          participants
          time_tracking
        ].freeze

        WIDGET_OPTIONS = {}.freeze

        def self.configuration
          {
            id: 3,
            name: 'Test Case',
            base_type: 'test_case',
            icon_name: "work-item-test-case"
          }
        end
      end
    end
  end
end
