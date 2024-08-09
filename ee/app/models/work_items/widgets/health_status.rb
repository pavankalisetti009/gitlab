# frozen_string_literal: true

module WorkItems
  module Widgets
    class HealthStatus < Base
      delegate :health_status, to: :work_item

      def self.quick_action_commands
        [:health_status, :clear_health_status]
      end

      def self.quick_action_params
        [:health_status]
      end

      def rolled_up_health_status
        # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/474916
        WorkItem.health_statuses.keys.map do |status|
          { health_status: status, count: 0 }
        end
      end
    end
  end
end
