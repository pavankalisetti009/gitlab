# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class UpdateWorkflowStatusService
      def initialize(workflow:, status_event:, current_user:)
        @workflow = workflow
        @status_event = status_event
        @current_user = current_user
      end

      def execute
        unless Feature.enabled?(:duo_workflow, @current_user)
          return error_response("Can not update workflow", :not_found)
        end

        unless @current_user.can?(:update_duo_workflow, @workflow)
          return error_response("Can not update workflow", :unauthorized)
        end

        case @status_event
        when "finish"
          unless @workflow.can_finish?
            return error_response("Can not finish workflow that has status #{@workflow.human_status_name}")
          end

          @workflow.finish
        when "drop"
          unless @workflow.can_drop?
            return error_response("Can not drop workflow that has status #{@workflow.human_status_name}")
          end

          @workflow.drop
        else
          return error_response("Can not update workflow status, unsupported event: #{@status_event}")
        end

        ServiceResponse.success(payload: { workflow: @workflow }, message: "Workflow status updated")
      end

      private

      def error_response(message, reason = :bad_request)
        ServiceResponse.error(message: message, reason: reason)
      end
    end
  end
end
