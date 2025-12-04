# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class CreateCheckpointService
      include ::Services::ReturnServiceResponses

      def initialize(workflow:, params:)
        @params = params
        @workflow = workflow
      end

      def execute
        checkpoint = @workflow.checkpoints.new(checkpoint_attributes)

        return error(checkpoint.errors.full_messages, :bad_request) unless checkpoint.save

        update_workflow_goal_if_first_checkpoint(checkpoint)
        GraphqlTriggers.workflow_events_updated(checkpoint)
        success(checkpoint: checkpoint)
      end

      def checkpoint_attributes
        @params.merge(workflow: @workflow)
      end

      # The workflow can be pre-created leaving its goal incomplete.
      def update_workflow_goal_if_first_checkpoint(checkpoint)
        # Using id.first because checkpoint ID is compound with the created_at,
        #  but minimum(:id) only retrieves the integer ID
        return unless @workflow.checkpoints.minimum(:id) == checkpoint.id.first

        goal = checkpoint.checkpoint.dig('channel_values', '__start__', 'goal')
        @workflow.update!(goal:) if goal.present?
      end
    end
  end
end
