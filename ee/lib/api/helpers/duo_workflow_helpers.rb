# frozen_string_literal: true

module API
  module Helpers
    module DuoWorkflowHelpers
      def push_ai_gateway_headers
        push_feature_flags

        Gitlab::AiGateway.public_headers(
          user: current_user,
          ai_feature_name: :duo_workflow,
          service_name: :duo_workflow_execute_workflow).each do |name, value|
          header(name, value)
        end
      end

      def push_feature_flags
        Gitlab::AiGateway.push_feature_flag(:duo_workflow_workhorse, current_user)
        Gitlab::AiGateway.push_feature_flag(:duo_workflow_web_chat_mutation_tools, current_user)
        Gitlab::AiGateway.push_feature_flag(:duo_workflow_work_item_tools, current_user)
        Gitlab::AiGateway.push_feature_flag(:expanded_ai_logging, current_user)
        Gitlab::AiGateway.push_feature_flag(:duo_workflow_prompt_registry, current_user)
        Gitlab::AiGateway.push_feature_flag(:use_duo_context_exclusion, current_user)
        Gitlab::AiGateway.push_feature_flag(:duo_agentic_chat_openai_gpt_5, current_user)
      end
    end
  end
end
