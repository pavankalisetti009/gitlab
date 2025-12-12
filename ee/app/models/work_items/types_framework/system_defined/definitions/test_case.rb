# frozen_string_literal: true

module WorkItems
  module TypesFramework
    module SystemDefined
      module Definitions
        module TestCase
          class << self
            def widgets
              %w[
                award_emoji
                current_user_todos
                custom_fields
                description
                linked_items
                notes
                notifications
                participants
                time_tracking
              ]
            end

            def widget_options
              {}
            end

            def configuration
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
  end
end
