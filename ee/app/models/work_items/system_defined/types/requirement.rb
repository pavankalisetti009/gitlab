# frozen_string_literal: true

module WorkItems
  module SystemDefined
    module Types
      module Requirement
        def self.configuration
          {
            id: 4,
            name: 'Requirement',
            base_type: 'requirement',
            icon_name: "work-item-requirement"
          }
        end
      end
    end
  end
end
