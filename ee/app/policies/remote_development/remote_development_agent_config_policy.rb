# frozen_string_literal: true

module RemoteDevelopment
  # TODO: clusterAgent.remoteDevelopmentAgentConfig GraphQL is deprecated - remove in 17.10 - https://gitlab.com/gitlab-org/gitlab/-/issues/480769
  class RemoteDevelopmentAgentConfigPolicy < BasePolicy
    condition(:can_read_cluster_agent) { can?(:read_cluster_agent, agent) }

    rule { can_read_cluster_agent }.enable :read_workspaces_agent_config

    private

    def agent
      @subject.agent
    end
  end
end
