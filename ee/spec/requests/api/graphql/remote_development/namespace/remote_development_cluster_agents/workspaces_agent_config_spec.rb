# frozen_string_literal: true

require 'spec_helper'
require_relative './shared'

RSpec.describe 'Query.namespace.remote_development_cluster_agents(filter: AVAILABLE)', feature_category: :workspaces do
  include GraphqlHelpers
  include StubFeatureFlags

  let_it_be(:user) { create(:user) }
  let(:agent_config_id) { subject['id'] }
  let_it_be(:current_user) { user }
  let_it_be(:available_agent) do
    create(:ee_cluster_agent, :in_group, :with_existing_workspaces_agent_config).tap do |agent|
      agent.project.namespace.add_maintainer(user)
    end
  end

  let_it_be(:agent_config) { available_agent.workspaces_agent_config }
  let_it_be(:namespace) { available_agent.project.namespace }
  let_it_be(:namespace_agent_mapping) do
    create(
      :remote_development_namespace_cluster_agent_mapping,
      user: user,
      agent: available_agent,
      namespace: namespace
    )
  end

  let(:fields) do
    <<~QUERY
      nodes {
        workspacesAgentConfig {
          #{all_graphql_fields_for('workspaces_agent_config'.classify, max_depth: 1)}
        }
      }
    QUERY
  end

  let(:query) do
    graphql_query_for(
      :namespace,
      { full_path: namespace.full_path },
      query_graphql_field(
        :remote_development_cluster_agents,
        { filter: :AVAILABLE },
        fields
      )
    )
  end

  subject do
    graphql_data.dig('namespace', 'remoteDevelopmentClusterAgents', 'nodes', 0, 'workspacesAgentConfig')
  end

  before do
    stub_licensed_features(remote_development: true)
  end

  context 'when the params are valid' do
    let(:expected_agent_config_id) do
      "gid://gitlab/RemoteDevelopment::WorkspacesAgentConfig/" \
        "#{agent_config.id}"
    end

    let(:expected_agent_config) do
      {
        'id' => expected_agent_config_id,
        'projectId' => agent_config.project_id,
        'enabled' => agent_config.enabled,
        'dnsZone' => agent_config.dns_zone,
        'networkPolicyEnabled' => agent_config.network_policy_enabled,
        'gitlabWorkspacesProxyNamespace' => agent_config.gitlab_workspaces_proxy_namespace,
        'workspacesQuota' => agent_config.workspaces_quota,
        'workspacesPerUserQuota' => agent_config.workspaces_per_user_quota,
        'defaultMaxHoursBeforeTermination' => agent_config.default_maxHours_before_termination,
        'maxHoursBeforeTerminationLimit' => agent_config.max_hours_before_termination_limit,
        'createdAt' => agent_config.created_at,
        'updatedAt' => agent_config.updated_at
      }
    end

    it 'returns cluster agents that are available for remote development in the namespace' do
      get_graphql(query, current_user: current_user)

      expect(agent_config_id).to eq(expected_agent_config_id)
    end
  end

  include_examples "checks for remote_development licensed feature"
end
