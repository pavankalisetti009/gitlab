# frozen_string_literal: true

module WorkItems
  module SystemDefined
    module Types
      module Issue
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
          error_tracking
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
          vulnerabilities
          linked_resources
          weight
          status
        ].freeze

        WIDGET_OPTIONS = {
          weight: { editable: true, rollup: false }
        }.freeze

        class << self
          def configuration
            {
              id: 1,
              name: 'Issue',
              base_type: 'issue',
              icon_name: "work-item-issue"
            }
          end

          def licenses_for_parent
            { 'epic' => :epics }
          end
        end
      end
    end
  end
end
