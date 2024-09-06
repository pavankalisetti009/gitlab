# frozen_string_literal: true

module RemoteDevelopment
  class WorkspacesAgentConfig < ApplicationRecord
    # NOTE: See the following comment for the reasoning behind the `Workspaces` prefix of this table/model:
    #       https://gitlab.com/gitlab-org/gitlab/-/issues/410045#note_1385602915
    include IgnorableColumns
    include Sortable

    UNLIMITED_QUOTA = -1
    MINIMUM_HOURS_BEFORE_TERMINATION = 1
    # NOTE: see the following issue for the reasoning behind this value being the hard maximum termination limit:
    #      https://gitlab.com/gitlab-org/gitlab/-/issues/471994
    MAXIMUM_HOURS_BEFORE_TERMINATION = 8760

    belongs_to :agent,
      class_name: 'Clusters::Agent', foreign_key: 'cluster_agent_id', inverse_of: :workspaces_agent_config

    # noinspection RailsParamDefResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
    has_many :workspaces, through: :agent, source: :workspaces

    validates :agent, presence: true
    validates :dns_zone, hostname: true
    validates :enabled, inclusion: { in: [true, false] }

    validates :network_policy_egress,
      json_schema: { filename: 'workspaces_agent_configs_network_policy_egress' }
    validates :network_policy_egress, 'remote_development/network_policy_egress': true
    validates :default_resources_per_workspace_container,
      json_schema: { filename: 'workspaces_agent_configs_workspace_container_resources' }
    validates :default_resources_per_workspace_container, 'remote_development/workspace_container_resources': true
    validates :max_resources_per_workspace,
      json_schema: { filename: 'workspaces_agent_configs_workspace_container_resources' }
    validates :max_resources_per_workspace, 'remote_development/workspace_container_resources': true
    validates :workspaces_quota, numericality: { only_integer: true, greater_than_or_equal_to: UNLIMITED_QUOTA }
    validates :workspaces_per_user_quota,
      numericality: { only_integer: true, greater_than_or_equal_to: UNLIMITED_QUOTA }
    validates :max_hours_before_termination_limit,
      numericality: {
        only_integer: true, greater_than_or_equal_to: :default_max_hours_before_termination,
        less_than_or_equal_to: MAXIMUM_HOURS_BEFORE_TERMINATION
      }
    validates :default_max_hours_before_termination,
      numericality: {
        only_integer: true, greater_than_or_equal_to: MINIMUM_HOURS_BEFORE_TERMINATION,
        less_than_or_equal_to: :max_hours_before_termination_limit
      }

    scope :by_cluster_agent_ids, ->(ids) { where(cluster_agent_id: ids) }
  end
end
