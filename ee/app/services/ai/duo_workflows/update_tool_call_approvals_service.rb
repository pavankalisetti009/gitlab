# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class UpdateToolCallApprovalsService
      def initialize(workflow:, tool_name:, tool_call_args:, current_user:)
        @workflow = workflow
        @tool_name = tool_name
        @tool_call_args = tool_call_args
        @current_user = current_user
      end

      def execute
        unless @current_user.can?(:update_duo_workflow, @workflow)
          return error_response("Can not update workflow", :unauthorized)
        end

        update_tool_call_approvals
      end

      private

      def update_tool_call_approvals
        # with_lock reloads the record before yielding, ensuring we read
        # the latest tool_call_approvals and prevent read-modify-write races.
        @workflow.with_lock('FOR UPDATE NOWAIT') do
          @workflow.add_tool_call_approval(tool_name: @tool_name, call_args: @tool_call_args)
          @workflow.save
        end

        if @workflow.errors.any?
          error_response("Failed to update tool_call_approvals: #{@workflow.errors.full_messages.join(', ')}")
        else
          ServiceResponse.success(
            payload: { workflow: @workflow },
            message: "Tool call approvals updated successfully"
          )
        end
      rescue ActiveRecord::LockWaitTimeout
        error_response("Workflow is currently being updated, please try again")
      end

      def error_response(message, reason = :bad_request)
        ServiceResponse.error(message: message, reason: reason)
      end
    end
  end
end
