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

        # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/439559
        0
      end
    end
  end
end
