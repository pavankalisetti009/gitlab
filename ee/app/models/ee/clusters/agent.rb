# frozen_string_literal: true

module EE
  module Clusters
    module Agent
      extend ActiveSupport::Concern

      prepended do
        has_one :agent_url_configuration, class_name: 'Clusters::Agents::UrlConfiguration', inverse_of: :agent

        has_many :vulnerability_reads, class_name: 'Vulnerabilities::Read', foreign_key: :casted_cluster_agent_id

        has_many :workspaces,
          class_name: 'RemoteDevelopment::Workspace',
          foreign_key: 'cluster_agent_id',
          inverse_of: :agent

        # TODO: clusterAgent.remoteDevelopmentAgentConfig GraphQL is deprecated - remove in 17.10 - https://gitlab.com/gitlab-org/gitlab/-/issues/480769
        has_one :remote_development_agent_config,
          class_name: 'RemoteDevelopment::RemoteDevelopmentAgentConfig',
          inverse_of: :agent,
          foreign_key: :cluster_agent_id

        has_one :workspaces_agent_config,
          class_name: 'RemoteDevelopment::WorkspacesAgentConfig',
          inverse_of: :agent,
          foreign_key: :cluster_agent_id

        has_many :remote_development_namespace_cluster_agent_mappings,
          class_name: 'RemoteDevelopment::RemoteDevelopmentNamespaceClusterAgentMapping',
          inverse_of: :agent,
          foreign_key: 'cluster_agent_id'

        scope :for_projects, ->(projects) { where(project: projects) }
        scope :with_workspaces_agent_config, -> { joins(:workspaces_agent_config) }
        scope :without_workspaces_agent_config, -> do
          includes(:workspaces_agent_config).where(workspaces_agent_config: { cluster_agent_id: nil })
        end
        scope :with_remote_development_enabled, -> do
          with_workspaces_agent_config.where(workspaces_agent_config: { enabled: true })
        end
      end
    end
  end
end
