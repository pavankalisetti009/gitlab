# frozen_string_literal: true

module WorkItems
  module Widgets
    class CustomFields < Base
      delegate :custom_field_values, to: :work_item
    end
  end
end
