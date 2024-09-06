# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/helpers/remote_development/integration_spec_helpers"

# rubocop:disable RSpec/MultipleMemoizedHelpers -- this is an integration test, it has a lot of fixtures, but only one example, so we don't need let_it_be
RSpec.describe "Full workspaces integration request spec", :freeze_time, feature_category: :workspaces do
  include GraphqlHelpers
  include RemoteDevelopment::IntegrationSpecHelpers
  include_context "with remote development shared fixtures"

  let(:agent_admin_user) { create(:user, name: "Agent Admin User") }
  # Agent setup
  let(:jwt_secret) { SecureRandom.random_bytes(Gitlab::Kas::SECRET_LENGTH) }
  let(:agent_token) { create(:cluster_agent_token, agent: agent) }
  let(:cluster_agents_query) do
    <<~GRAPHQL
      query {
          namespace(fullPath: "#{common_parent_namespace.full_path}") {
            remoteDevelopmentClusterAgents(filter: AVAILABLE) {
              nodes {
                id
                workspacesAgentConfig {
                  id
                  projectId
                  enabled
                  gitlabWorkspacesProxyNamespace
                  networkPolicyEnabled
                  dnsZone
                  workspacesPerUserQuota
                  workspacesQuota
                  defaultMaxHoursBeforeTermination
                  maxHoursBeforeTerminationLimit
                }
              }
            }
          }
        }
    GRAPHQL
  end

  let(:gitlab_workspaces_proxy_namespace) { "gitlab-workspaces" }
  let(:dns_zone) { "integration-spec-workspaces.localdev.me" }
  let(:network_policy_enabled) { true }
  let(:workspaces_per_user_quota) { 20 }
  let(:workspaces_quota) { 100 }
  let(:default_max_hours_before_termination) { 48 }
  let(:max_hours_before_termination_limit) { 240 }

  let(:expected_agent_config) do
    {
      "id" => "gid://gitlab/RemoteDevelopment::WorkspacesAgentConfig/#{workspaces_agent_config.id}",
      "projectId" => agent_project.id.to_s,
      "enabled" => true,
      "gitlabWorkspacesProxyNamespace" => "gitlab-workspaces",
      "networkPolicyEnabled" => network_policy_enabled,
      "dnsZone" => dns_zone,
      "workspacesPerUserQuota" => workspaces_per_user_quota,
      "workspacesQuota" => workspaces_quota,
      "defaultMaxHoursBeforeTermination" => default_max_hours_before_termination,
      "maxHoursBeforeTerminationLimit" => max_hours_before_termination_limit
    }
  end

  let(:user) { create(:user, name: "Workspaces User", email: "workspaces-user@example.org") }
  let(:current_user) { user }
  let(:common_parent_namespace_name) { "common-parent-group" }
  let(:common_parent_namespace) { create(:group, name: common_parent_namespace_name, owners: agent_admin_user) }
  let(:agent_project_namespace) do
    create(:group, name: "agent-project-group", parent: common_parent_namespace)
  end

  let(:workspace_project_namespace_name) { "workspace-project-group" }
  let(:workspace_project_namespace) do
    create(:group, name: workspace_project_namespace_name, parent: common_parent_namespace)
  end

  let(:workspace_project_name) { "workspace-project" }
  let(:workspace_namespace_path) { "#{common_parent_namespace_name}/#{workspace_project_namespace_name}" }
  let(:random_string) { "abcdef" }
  let(:devfile_ref) { "master" }
  let(:devfile_path) { ".devfile.yaml" }
  let(:devfile_fixture_name) { "example.devfile.yaml" }
  let(:devfile_yaml) do
    read_devfile(
      devfile_fixture_name,
      namespace_path: "#{common_parent_namespace_name}/#{workspace_project_namespace_name}",
      project_name: workspace_project_name
    )
  end

  let(:expected_processed_devfile_yaml) do
    example_processed_devfile(
      namespace_path: "#{common_parent_namespace_name}/#{workspace_project_namespace_name}",
      project_name: workspace_project_name
    )
  end

  let(:expected_processed_devfile) { YAML.safe_load(expected_processed_devfile_yaml).to_h }
  let(:editor) { "webide" }
  let(:workspace_root) { "/projects" }
  let(:user_provided_variables) do
    [
      { key: "VAR1", value: "value 1", type: :environment },
      { key: "VAR2", value: "value 2", type: :environment }
    ]
  end

  let(:expected_static_variables) do
    # rubocop:disable Layout/LineLength -- keep them on one line for easier readability and editability
    [
      { key: "GIT_CONFIG_COUNT", type: :environment, value: "3" },
      { key: "GIT_CONFIG_KEY_0", type: :environment, value: "credential.helper" },
      { key: "GIT_CONFIG_KEY_1", type: :environment, value: "user.name" },
      { key: "GIT_CONFIG_KEY_2", type: :environment, value: "user.email" },
      { key: "GIT_CONFIG_VALUE_0", type: :environment, value: "/.workspace-data/variables/file/gl_git_credential_store.sh" },
      { key: "GIT_CONFIG_VALUE_1", type: :environment, value: "Workspaces User" },
      { key: "GIT_CONFIG_VALUE_2", type: :environment, value: "workspaces-user@example.org" },
      { key: "GL_EDITOR_EXTENSIONS_GALLERY_ITEM_URL", type: :environment, value: "https://open-vsx.org/vscode/item" },
      { key: "GL_EDITOR_EXTENSIONS_GALLERY_RESOURCE_URL_TEMPLATE", type: :environment, value: "https://open-vsx.org/vscode/unpkg/{publisher}/{name}/{version}/{path}" },
      { key: "GL_EDITOR_EXTENSIONS_GALLERY_SERVICE_URL", type: :environment, value: "https://open-vsx.org/vscode/gallery" },
      { key: "GL_GIT_CREDENTIAL_STORE_FILE_PATH", type: :environment, value: "/.workspace-data/variables/file/gl_git_credential_store.sh" },
      { key: "GL_TOKEN_FILE_PATH", type: :environment, value: "/.workspace-data/variables/file/gl_token" },
      { key: "GL_WORKSPACE_DOMAIN_TEMPLATE", type: :environment, value: "${PORT}-workspace-#{agent.id}-#{user.id}-#{random_string}.#{dns_zone}" },
      { key: "GITLAB_WORKFLOW_INSTANCE_URL", type: :environment, value: Gitlab::Routing.url_helpers.root_url },
      { key: "GITLAB_WORKFLOW_TOKEN_FILE", type: :environment, value: "/.workspace-data/variables/file/gl_token" },
      { key: "gl_git_credential_store.sh", type: :file, value: RemoteDevelopment::WorkspaceOperations::Create::WorkspaceVariables::GIT_CREDENTIAL_STORE_SCRIPT },
      { key: "gl_token", type: :file, value: /glpat-.+/ }
    ]
    # rubocop:enable Layout/LineLength
  end

  let(:workspace_project) do
    files = { devfile_path => devfile_yaml }
    create(:project, :in_group, :custom_repo, path: workspace_project_name, files: files,
      namespace: workspace_project_namespace, developers: user)
  end

  let(:agent_project) do
    create(:project, path: "agent-project", developers: user, namespace: agent_project_namespace)
  end

  let(:agent) do
    create(:ee_cluster_agent, project: agent_project, created_by_user: agent_admin_user, project_id: agent_project.id)
  end

  # TODO: We should create the workspaces_agent_config via an API call to update the agent config
  #       with the relevant fixture values in its config file to represent a remote_development enabled agent.
  #       And, as we migrate the settings from the agent config file to the settings UI, we should add
  #       simulated API calls for setting the values that way too.
  let!(:workspaces_agent_config) do
    create(
      :workspaces_agent_config,
      agent: agent,
      gitlab_workspaces_proxy_namespace: gitlab_workspaces_proxy_namespace,
      dns_zone: dns_zone,
      network_policy_enabled: network_policy_enabled,
      workspaces_per_user_quota: workspaces_per_user_quota,
      workspaces_quota: workspaces_quota,
      default_max_hours_before_termination: default_max_hours_before_termination,
      max_hours_before_termination_limit: max_hours_before_termination_limit
    )
  end

  let(:namespace_create_remote_development_cluster_agent_mapping_create_mutation_args) do
    {
      namespace_id: common_parent_namespace.to_global_id.to_s,
      cluster_agent_id: agent.to_global_id.to_s
    }
  end

  before do
    stub_licensed_features(remote_development: true)
    allow(SecureRandom).to receive(:alphanumeric) { random_string }

    allow(Gitlab::Kas).to receive(:secret).and_return(jwt_secret)

    allow(workspace_project.repository).to receive_message_chain(:blob_at_branch, :data) { devfile_yaml }
  end

  def do_create_mapping
    do_graphql_mutation_post(
      name: :namespace_create_remote_development_cluster_agent_mapping,
      input: namespace_create_remote_development_cluster_agent_mapping_create_mutation_args,
      user: agent_admin_user
    )
  end

  def fetch_agent_config
    get_graphql(cluster_agents_query, current_user: agent_admin_user)

    expect(
      graphql_data_at(:namespace, :remoteDevelopmentClusterAgents, :nodes, 0, :workspacesAgentConfig)
    ).to eq(expected_agent_config)

    graphql_data_at(:namespace, :remoteDevelopmentClusterAgents, :nodes, 0, :id)
  end

  # rubocop:disable Metrics/AbcSize -- We want this to stay a single method
  def do_create_workspace(cluster_agent_id)
    create_mutation_response = do_graphql_mutation_post(
      name: :workspace_create,
      input: workspace_create_mutation_args(cluster_agent_id),
      user: user
    )

    workspace_gid = create_mutation_response.fetch("workspace").fetch("id")
    workspace_id = GitlabSchema.parse_gid(workspace_gid, expected_type: ::RemoteDevelopment::Workspace).model_id
    workspace = ::RemoteDevelopment::Workspace.find(workspace_id)

    # NOTE: Where possible, avoid explicit assertions here and replace them with assertions on the
    #       response_json data sent in the reconciliation loop "simulate_N_poll" methods.

    expect(workspace.user).to eq(user)
    expect(workspace.agent).to eq(agent)
    # noinspection RubyResolve
    expect(workspace.desired_state_updated_at).to eq(Time.current)
    expect(workspace.name).to eq("workspace-#{agent.id}-#{user.id}-#{random_string}")
    expect(workspace.namespace).to eq("gl-rd-ns-#{agent.id}-#{user.id}-#{random_string}")
    expect(workspace.editor).to eq("webide")
    expect(workspace.url).to eq(URI::HTTPS.build({
      host: "60001-#{workspace.name}.#{dns_zone}",
      query: {
        folder: "#{workspace_root}/#{workspace_project.path}"
      }.to_query
    }).to_s)
    # noinspection RubyResolve
    expect(workspace.devfile).to eq(devfile_yaml)
    actual_processed_devfile = YAML.safe_load(workspace.processed_devfile).to_h
    expect(actual_processed_devfile.fetch("components")).to eq(expected_processed_devfile.fetch("components"))
    expect(actual_processed_devfile).to eq(expected_processed_devfile)

    all_expected_vars = (expected_static_variables + user_provided_variables).sort_by { |v| v[:key] }
    # NOTE: We convert the actual records into hashes and sort them as a hash rather than ordering in
    #       ActiveRecord, to account for platform- or db-specific sorting differences.
    types = RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES
    all_actual_vars =
      RemoteDevelopment::WorkspaceVariable
        .where(workspace: workspace)
        .map { |v| { key: v.key, type: types.invert[v.variable_type], value: v.value } }
        .sort_by { |v| v[:key] }

    # Check just keys first, to get an easy failure message if a new key has been added
    expect(all_actual_vars.pluck(:key)).to match_array(all_expected_vars.pluck(:key))

    # Then check the full attributes for all vars except gl_token, which must be compared as a regex
    expected_without_regexes = all_expected_vars.reject { |v| v[:key] == "gl_token" }
    actual_without_regexes = all_actual_vars.reject { |v| v[:key] == "gl_token" }
    expect(expected_without_regexes).to match(actual_without_regexes)

    expected_gl_token_value = expected_static_variables.find { |var| var[:key] == "gl_token" }[:value]
    actual_gl_token_value = all_actual_vars.find { |var| var[:key] == "gl_token" }[:value]
    expect(actual_gl_token_value).to match(expected_gl_token_value)

    workspace
  end

  # rubocop:enable Metrics/AbcSize

  def workspace_create_mutation_args(cluster_agent_id)
    {
      desired_state: RemoteDevelopment::WorkspaceOperations::States::RUNNING,
      editor: "webide",
      max_hours_before_termination: 24,
      cluster_agent_id: cluster_agent_id,
      project_id: workspace_project.to_global_id.to_s,
      devfile_ref: devfile_ref,
      devfile_path: devfile_path,
      variables: user_provided_variables.each_with_object([]) do |variable, arr|
        arr << variable.merge(type: variable[:type].to_s.upcase)
      end
    }
  end

  def do_stop_workspace(workspace)
    workspace_update_mutation_args = {
      id: global_id_of(workspace),
      desired_state: RemoteDevelopment::WorkspaceOperations::States::STOPPED
    }

    do_graphql_mutation_post(
      name: :workspace_update,
      input: workspace_update_mutation_args,
      user: user
    )

    # NOTE: Where possible, avoid explicit assertions here and replace them with assertions on the
    #       response_json data sent in the reconciliation loop "simulate_N_poll" methods.

    # noinspection RubyResolve
    expect(workspace.reload.desired_state_updated_at).to eq(Time.current)
  end

  def do_graphql_mutation_post(name:, input:, user:)
    mutation = graphql_mutation(name, input)
    post_graphql_mutation(mutation, current_user: user)
    expect_graphql_errors_to_be_empty
    mutation_response = graphql_mutation_response(name)
    expect(mutation_response.fetch("errors")).to eq([])
    mutation_response
  end

  def simulate_agentk_reconcile_post(workspace_agent_infos:, update_type:, agent_token:)
    # Add `travel(...)` based on full or partial reconciliation interval in response body
    partial_reconciliation_interval_seconds =
      RemoteDevelopment::Settings
        .get([:full_reconciliation_interval_seconds, :partial_reconciliation_interval_seconds])
        .fetch(:partial_reconciliation_interval_seconds)
        .to_i
    travel(partial_reconciliation_interval_seconds)

    jwt_token = JWT.encode(
      { "iss" => Gitlab::Kas::JWT_ISSUER, 'aud' => Gitlab::Kas::JWT_AUDIENCE },
      Gitlab::Kas.secret,
      "HS256"
    )
    agent_token_headers = {
      "Authorization" => "Bearer #{agent_token.token}",
      Gitlab::Kas::INTERNAL_API_KAS_REQUEST_HEADER => jwt_token
    }

    post_params = {
      update_type: update_type,
      workspace_agent_infos: workspace_agent_infos
    }
    reconcile_url = api("/internal/kubernetes/modules/remote_development/reconcile", personal_access_token: agent_token)
    post reconcile_url, params: post_params, headers: agent_token_headers, as: :json

    expect(response).to have_gitlab_http_status(:created)
    response_json = json_response.deep_symbolize_keys

    reconciliation_interval_from_response =
      response_json.fetch(:settings).fetch(:partial_reconciliation_interval_seconds).to_i
    expect(reconciliation_interval_from_response).to eq(partial_reconciliation_interval_seconds)

    response_json
  end

  it "successfully exercises the full lifecycle of a workspace", :unlimited_max_formatted_output_length do
    # CREATE THE MAPPING VIA GRAPHQL API, SO WE HAVE PROPER AUTHORIZATION
    do_create_mapping

    # FETCH THE AGENT CONFIG VIA THE GRAPHQL API, SO WE CAN USE ITS VALUES WHEN CREATING WORKSPACE
    cluster_agent_id = fetch_agent_config

    # DO THE INITAL WORKSPACE CREATION VIA GRAPHQL API
    workspace = do_create_workspace(cluster_agent_id)

    additional_args_for_expected_config_to_apply =
      build_additional_args_for_expected_config_to_apply(
        network_policy_enabled: network_policy_enabled,
        dns_zone: dns_zone,
        namespace_path: workspace_project_namespace.full_path,
        project_name: workspace_project_name
      )

    # SIMULATE FIRST POLL FROM AGENTK TO PICK UP NEW WORKSPACE
    simulate_first_poll(
      workspace: workspace.reload,
      **additional_args_for_expected_config_to_apply
    ) do |workspace_agent_infos:, update_type:|
      simulate_agentk_reconcile_post(
        workspace_agent_infos: workspace_agent_infos,
        update_type: update_type,
        agent_token: agent_token
      )
    end

    # noinspection RubyResolve
    expect(workspace.reload.responded_to_agent_at).to eq(Time.current)

    # SIMULATE SECOND POLL FROM AGENTK TO UPDATE WORKSPACE TO RUNNING STATE
    simulate_second_poll(workspace: workspace.reload) do |workspace_agent_infos:, update_type:|
      simulate_agentk_reconcile_post(
        workspace_agent_infos: workspace_agent_infos,
        update_type: update_type,
        agent_token: agent_token
      )
    end

    # UPDATE WORKSPACE DESIRED_STATE TO STOPPED VIA GRAPHQL API
    do_stop_workspace(workspace)

    # SIMULATE THIRD POLL FROM AGENTK TO UPDATE WORKSPACE TO STOPPING STATE
    simulate_third_poll(
      workspace: workspace.reload,
      **additional_args_for_expected_config_to_apply
    ) do |workspace_agent_infos:, update_type:|
      simulate_agentk_reconcile_post(
        agent_token: agent_token,
        workspace_agent_infos: workspace_agent_infos,
        update_type: update_type
      )
    end

    # SIMULATE FOURTH POLL FROM AGENTK TO UPDATE WORKSPACE TO STOPPED STATE
    simulate_fourth_poll(workspace: workspace.reload) do |workspace_agent_infos:, update_type:|
      simulate_agentk_reconcile_post(
        agent_token: agent_token,
        workspace_agent_infos: workspace_agent_infos,
        update_type: update_type
      )
    end

    # SIMULATE FIFTH POLL FROM AGENTK FOR PARTIAL RECONCILE TO SHOW NO RAILS_INFOS ARE SENT
    simulate_fifth_poll do |workspace_agent_infos:, update_type:|
      simulate_agentk_reconcile_post(
        agent_token: agent_token,
        workspace_agent_infos: workspace_agent_infos,
        update_type: update_type
      )
    end

    # SIMULATE SIXTH POLL FROM AGENTK FOR FULL RECONCILE TO SHOW ALL WORKSPACES ARE SENT IN RAILS_INFOS
    simulate_sixth_poll(
      workspace: workspace.reload,
      **additional_args_for_expected_config_to_apply
    ) do |workspace_agent_infos:, update_type:|
      simulate_agentk_reconcile_post(
        agent_token: agent_token,
        workspace_agent_infos: workspace_agent_infos,
        update_type: update_type
      )
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
