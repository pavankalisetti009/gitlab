# frozen_string_literal: true

module WorkItems
  module SystemDefined
    module Types
      module Objective
        def self.configuration
          {
            id: 6,
            name: 'Objective',
            base_type: 'objective',
            icon_name: "work-item-objective"
          }
        end
      end
    end
  end
end
