# frozen_string_literal: true

module API
  module Helpers
    module DuoWorkflowHelpers
      def push_ai_gateway_headers
        push_feature_flags

        Gitlab::AiGateway.public_headers(user: current_user, service_name: :duo_workflow).each do |name, value|
          header(name, value)
        end
      end

      private

      def push_feature_flags
        Gitlab::AiGateway.push_feature_flag(:batch_duo_workflow_planner_tasks, current_user)
        Gitlab::AiGateway.push_feature_flag(:duo_workflow_claude_3_7, current_user)
        Gitlab::AiGateway.push_feature_flag(:duo_workflow_better_tool_messages, current_user)
      end
    end
  end
end
