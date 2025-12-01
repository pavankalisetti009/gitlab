# frozen_string_literal: true

module WorkItems
  module SystemDefined
    module Types
      module KeyResult
        def self.configuration
          {
            id: 7,
            name: 'Key Result',
            base_type: 'key_result',
            icon_name: "work-item-keyresult"
          }
        end
      end
    end
  end
end
