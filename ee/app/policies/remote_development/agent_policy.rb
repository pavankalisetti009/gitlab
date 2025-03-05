# frozen_string_literal: true

module RemoteDevelopment
  module AgentPolicy
    extend ActiveSupport::Concern

    included do
      rule { admin_agent }.policy do
        enable :admin_organization_cluster_agent_mapping
        enable :admin_remote_development_cluster_agent_mapping
      end

      rule { can?(:maintainer_access) }.enable :read_remote_development_cluster_agent_mapping
    end
  end
end
