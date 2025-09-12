# frozen_string_literal: true

module Ai
  module FlowTriggers
    class CreateService < BaseService
      def initialize(project:, current_user:)
        @project = project
        @current_user = current_user
      end

      def execute(params)
        super do
          project.ai_flow_triggers.create(params)
        end
      end
    end
  end
end
