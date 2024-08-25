# frozen_string_literal: true

module Types
  module RemoteDevelopment
    class WorkspacesAgentConfigType < ::Types::BaseObject
      graphql_name 'WorkspacesAgentConfig'
      description 'Represents a workspaces agent config'

      authorize :read_workspaces_agent_config

      field :id, ::Types::GlobalIDType[::RemoteDevelopment::WorkspacesAgentConfig],
        null: false, description: 'Global ID of the workspaces agent config.'

      field :cluster_agent, ::Types::Clusters::AgentType,
        null: false, description: 'Cluster agent that the workspaces agent config belongs to.'

      field :project_id, GraphQL::Types::ID,
        null: true, description: 'ID of the project that the workspaces agent config belongs to.'

      field :enabled, GraphQL::Types::Boolean,
        null: false, description: 'Indicates whether remote development is enabled for the GitLab agent.'

      field :dns_zone, GraphQL::Types::String,
        null: false, description: 'DNS zone where workspaces are available.'

      field :network_policy_enabled, GraphQL::Types::Boolean,
        null: false, description: 'Whether the network policy of the workspaces agent config is enabled.'

      field :gitlab_workspaces_proxy_namespace, GraphQL::Types::String,
        null: false, description: 'Namespace where gitlab-workspaces-proxy is installed.'

      field :workspaces_quota, GraphQL::Types::Int,
        null: false, description: 'Maximum number of workspaces for the GitLab agent.'

      field :workspaces_per_user_quota, GraphQL::Types::Int, # rubocop:disable GraphQL/ExtractType -- We don't want to extract this to a type, it's just an integer field
        null: false, description: 'Maximum number of workspaces per user.'

      field :default_max_hours_before_termination, GraphQL::Types::Int, null: false,
        description: 'Default max hours before worksapce termination of the workspaces agent config.'

      field :max_hours_before_termination_limit, GraphQL::Types::Int, null: false,
        description: 'Max hours before worksapce termination limit of the workspaces agent config.'

      field :created_at, Types::TimeType,
        null: false, description: 'Timestamp of when the workspaces agent config was created.'

      field :updated_at, Types::TimeType, null: false,
        description: 'Timestamp of the last update to any mutable workspaces agent config property.'
    end
  end
end
