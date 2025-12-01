# frozen_string_literal: true

module WorkItems
  module SystemDefined
    module Types
      module Objective
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
          milestone
          notes
          notifications
          participants
          progress
        ].freeze

        WIDGET_OPTIONS = {}.freeze

        def self.configuration
          {
            id: 6,
            name: 'Objective',
            base_type: 'objective',
            icon_name: "work-item-objective"
          }
        end

        def self.licence_name
          :okrs
        end
      end
    end
  end
end
