# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class WorkflowPresenter < Gitlab::View::Presenter::Delegated
      presents ::Ai::DuoWorkflows::Workflow, as: :workflow

      def human_status
        workflow.human_status_name
      end

      def mcp_enabled
        workflow.mcp_enabled?
      end

      def agent_privileges_names
        workflow.agent_privileges.map do |privilege|
          ::Ai::DuoWorkflows::Workflow::AgentPrivileges::ALL_PRIVILEGES[privilege][:name]
        end
      end

      def pre_approved_agent_privileges_names
        workflow.pre_approved_agent_privileges.map do |privilege|
          ::Ai::DuoWorkflows::Workflow::AgentPrivileges::ALL_PRIVILEGES[privilege][:name]
        end
      end

      def first_checkpoint
        workflow.checkpoints.earliest
      end

      def latest_checkpoint
        workflow.checkpoints.latest
      end
    end
  end
end
