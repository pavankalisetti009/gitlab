# frozen_string_literal: true

module WorkItems
  module Widgets
    class Weight < Base
      def self.quick_action_commands
        [:weight, :clear_weight]
      end

      def self.quick_action_params
        [:weight]
      end

      def weight
        return unless widget_options[:editable]

        work_item.weight
      end

      def rolled_up_weight
        return unless widget_options[:rollup]

        # We cannot use `#sum(:weight)` because ActiveRecord returns 0 when PG returns NULL.
        # We need to distinguish between a sum of 0 and the absence of descendant weights.
        work_item.descendants
          .where(work_item_type_id: WorkItems::Type.default_issue_type)
          .pick('SUM(weight)')
      end
    end
  end
end
