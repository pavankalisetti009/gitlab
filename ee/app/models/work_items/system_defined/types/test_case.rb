# frozen_string_literal: true

module WorkItems
  module SystemDefined
    module Types
      module TestCase
        def self.configuration
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
