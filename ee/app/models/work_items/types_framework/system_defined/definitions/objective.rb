# frozen_string_literal: true

module WorkItems
  module TypesFramework
    module SystemDefined
      module Definitions
        module Objective
          class << self
            def widgets
              %w[
                assignees
                award_emoji
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
                progress
              ]
            end

            def widget_options
              {
                progress: { show_popover: true },
                hierarchy: { auto_expand_tree_on_move: true }
              }
            end

            def configuration
              {
                id: 6,
                name: 'Objective',
                base_type: 'objective',
                icon_name: "work-item-objective"
              }
            end

            def license_name
              :okrs
            end
          end
        end
      end
    end
  end
end
