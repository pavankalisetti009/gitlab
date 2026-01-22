# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class UpdateWorkflowStatusService
      include Concerns::WorkflowEventTracking

      TRACKABLE_EVENT_STATUSES = {
        'start' => 'agent_platform_session_started',
        'finish' => 'agent_platform_session_finished',
        'drop' => 'agent_platform_session_dropped',
        'stop' => 'agent_platform_session_stopped',
        'resume' => 'agent_platform_session_resumed'
      }.freeze

      AUDIT_EVENT_CONFIG = {
        'start' => { name: 'duo_session_started', message: 'Started Duo session' },
        'finish' => { name: 'duo_session_finished', message: 'Completed Duo session' },
        'drop' => { name: 'duo_session_failed', message: 'Duo session failed' },
        'stop' => { name: 'duo_session_stopped', message: 'Duo session stopped' }
      }.freeze

      def initialize(workflow:, status_event:, current_user:)
        @workflow = workflow
        @status_event = status_event
        @current_user = current_user
      end

      def execute
        unless @current_user.can?(:update_duo_workflow, @workflow)
          return error_response("Can not update workflow", :unauthorized)
        end

        handle_status_event
      end

      private

      def cancel_associated_pipelines
        pipelines = @workflow.associated_pipelines
        failed_cancellations = []

        pipelines.each do |pipeline|
          next unless pipeline.cancelable?

          result = ::Ci::CancelPipelineService.new(
            pipeline: pipeline,
            current_user: @current_user
          ).execute

          failed_cancellations << "Pipeline #{pipeline.id}: #{result.message}" if result.error?
        end

        if failed_cancellations.any?
          error_msg = "Failed to cancel some pipelines: #{failed_cancellations.join(', ')}"
          return error_response(error_msg)
        end

        ServiceResponse.success
      end

      def handle_status_event
        workflow_events = ::Ai::DuoWorkflows::Workflow.state_machines[:status].events.map { |event| event.name.to_s }

        unless workflow_events.include?(@status_event)
          return error_response("Can not update workflow status, unsupported event: #{@status_event}")
        end

        unless @current_user.can?(:update_duo_workflow, @workflow)
          return error_response("You do not have permission to cancel this session.", :unauthorized)
        end

        if ::Ai::DuoWorkflows::Workflow.target_status_for_event(@status_event.to_sym) == @workflow.status_name
          return ServiceResponse.success(payload: { workflow: @workflow },
            message: "Workflow already in status #{@workflow.human_status_name}")
        end

        unless @workflow.status_events.include?(@status_event.to_sym)
          return error_response("Can not #{@status_event} workflow that has status #{@workflow.human_status_name}")
        end

        if @status_event == 'stop'
          pipeline_cancellation_result = cancel_associated_pipelines
          return pipeline_cancellation_result if pipeline_cancellation_result.error?
        end

        @workflow.fire_status_event(@status_event)

        track_agent_platform_session_event

        audit_event_for_status_change

        update_workflow_system_note(@workflow)

        GraphqlTriggers.workflow_events_updated(@workflow.checkpoints.last) if @workflow.checkpoints.any?

        ServiceResponse.success(payload: { workflow: @workflow }, message: "Workflow status updated")
      end

      def track_agent_platform_session_event
        event_name = TRACKABLE_EVENT_STATUSES[@status_event]
        return unless event_name

        track_workflow_event(event_name, @workflow)
      end

      def error_response(message, reason = :bad_request)
        ServiceResponse.error(message: message, reason: reason)
      end

      def audit_event_for_status_change
        config = AUDIT_EVENT_CONFIG[@status_event]
        return unless config

        audit_context = {
          name: config[:name],
          author: @current_user,
          scope: @workflow.project || @workflow.namespace,
          target: @workflow,
          target_details: "#{@workflow.workflow_definition} session #{@workflow.id}",
          message: config[:message]
        }

        begin
          ::Gitlab::Audit::Auditor.audit(audit_context)
        rescue StandardError => e
          Gitlab::ErrorTracking.track_exception(e, workflow_id: @workflow.id)
        end
      end

      def update_workflow_system_note(workflow)
        noteable = workflow.issue
        return unless noteable
        return unless noteable.respond_to?(:project) && noteable.project.present?

        case @status_event
        when 'finish'
          SystemNoteService.agent_session_completed(
            noteable,
            noteable.project,
            workflow.id
          )
        when 'drop', 'stop'
          reason = @status_event == 'drop' ? 'dropped' : 'stopped'
          SystemNoteService.agent_session_failed(
            noteable,
            noteable.project,
            workflow.id,
            reason
          )
        end
      rescue StandardError => e
        Gitlab::ErrorTracking.track_exception(
          e,
          workflow_id: workflow.id,
          noteable_type: noteable.class.name,
          noteable_id: noteable.id
        )
      end
    end
  end
end
