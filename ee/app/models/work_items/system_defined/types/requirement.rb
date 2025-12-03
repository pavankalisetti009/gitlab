# frozen_string_literal: true

module WorkItems
  module SystemDefined
    module Types
      module Requirement
        WIDGETS = %w[
          award_emoji
          current_user_todos
          custom_fields
          description
          linked_items
          notes
          notifications
          participants
          requirement_legacy
          verification_status
          test_reports
          time_tracking
        ].freeze

        WIDGET_OPTIONS = {}.freeze

        class << self
          def configuration
            {
              id: 4,
              name: 'Requirement',
              base_type: 'requirement',
              icon_name: "work-item-requirement"
            }
          end

          def license_name
            :requirements
          end
        end
      end
    end
  end
end
