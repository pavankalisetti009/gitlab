# frozen_string_literal: true

module RemoteDevelopment
  class WorkspacesAgentConfigPolicy < BasePolicy
    condition(:can_read_cluster_agent) { can?(:read_cluster_agent, agent) }

    rule { can_read_cluster_agent }.enable :read_workspaces_agent_config

    private

    def agent
      @subject.agent
    end
  end
end
