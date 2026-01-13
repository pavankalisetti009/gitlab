# frozen_string_literal: true

module Ai
  module FlowTriggers
    class CreateService < BaseService
      def initialize(project:, current_user:)
        @project = project
        @current_user = current_user
      end

      def execute(params)
        return disallow_new_external_agent_error unless new_external_agents_allowed?

        super do
          project.ai_flow_triggers.create(params)
        end
      end
    end
  end
end
