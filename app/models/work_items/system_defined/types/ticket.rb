# frozen_string_literal: true

module WorkItems
  module SystemDefined
    module Types
      module Ticket
        WIDGETS = %w[
          assignees
          award_emoji
          crm_contacts
          current_user_todos
          custom_fields
          description
          designs
          development
          email_participants
          health_status
          hierarchy
          iteration
          labels
          linked_items
          milestone
          notes
          notifications
          participants
          start_and_due_date
          time_tracking
          weight
        ].freeze

        WIDGET_OPTIONS = {
          weight: { editable: true, rollup: false }
        }.freeze

        def self.configuration
          {
            id: 9,
            name: 'Ticket',
            base_type: 'ticket',
            icon_name: "work-item-ticket"
          }
        end
      end
    end
  end
end
