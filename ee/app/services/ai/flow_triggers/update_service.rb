# frozen_string_literal: true

module Ai
  module FlowTriggers
    class UpdateService < BaseService
      def initialize(project:, current_user:, trigger:)
        @project = project
        @current_user = current_user
        @trigger = trigger
      end

      def execute(params)
        super do
          @trigger.update(params)
          @trigger
        end
      end
    end
  end
end
