# frozen_string_literal: true

module WorkItems
  module SystemDefined
    module Types
      module Epic
        def self.configuration
          {
            id: 8,
            name: 'Epic',
            base_type: 'epic',
            icon_name: "work-item-epic"
          }
        end
      end
    end
  end
end
