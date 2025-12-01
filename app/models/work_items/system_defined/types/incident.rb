# frozen_string_literal: true

module WorkItems
  module SystemDefined
    module Types
      module Incident
        WIDGETS = %w[
          assignees
          award_emoji
          crm_contacts
          current_user_todos
          custom_fields
          description
          development
          email_participants
          hierarchy
          iteration
          labels
          linked_items
          linked_resources
          milestone
          notes
          notifications
          participants
          time_tracking
        ].freeze

        WIDGET_OPTIONS = {}.freeze

        def self.configuration
          {
            id: 2,
            name: 'Incident',
            base_type: 'incident',
            icon_name: 'work-item-incident'
          }
        end
      end
    end
  end
end
