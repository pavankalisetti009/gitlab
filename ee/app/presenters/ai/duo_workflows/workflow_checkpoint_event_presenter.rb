# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class WorkflowCheckpointEventPresenter < Gitlab::View::Presenter::Delegated
      presents ::Ai::DuoWorkflows::Checkpoint, as: :event

      DuoMessage = Struct.new(:content, :message_type, :status, :tool_info,
        :timestamp, :correlation_id, :role, keyword_init: true)

      def timestamp
        event.thread_ts
      end

      def parent_timestamp
        event.parent_ts
      end

      def workflow_status
        event.workflow.status
      end

      def workflow_goal
        Gitlab::AppLogger.info(
          workflow_gid: event.workflow.to_gid,
          checkpoint_ts: event.thread_ts,
          message: 'Serialising checkpoint'
        )
        event.workflow.goal
      end

      def workflow_definition
        event.workflow.workflow_definition
      end

      def execution_status
        graph_state = event.checkpoint.dig('channel_values', 'status')
        return graph_state unless graph_state.nil? || graph_state == 'Not Started'

        event.workflow.human_status_name.titleize
      end

      def duo_messages
        checkpoint = event.checkpoint
        return [] unless checkpoint

        ui_chat_log = checkpoint.dig('channel_values', 'ui_chat_log')
        return [] unless ui_chat_log.is_a?(Array)

        ui_chat_log.map do |message|
          msg = message.slice('content', 'message_type', 'status', 'tool_info', 'timestamp', 'correlation_id', 'role')
          DuoMessage.new(**msg.symbolize_keys)
        end
      end
    end
  end
end
