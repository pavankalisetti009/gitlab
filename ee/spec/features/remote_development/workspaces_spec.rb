# frozen_string_literal: true

require 'spec_helper'
require_relative "../../support/helpers/remote_development/integration_spec_helpers"

RSpec.describe 'Remote Development workspaces', :api, :js, feature_category: :workspaces do
  include RemoteDevelopment::IntegrationSpecHelpers

  include_context 'with remote development shared fixtures'
  include_context 'file upload requests helpers'

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, name: 'test-group', developers: user, owners: user) }
  let_it_be(:devfile_path) { '.devfile.yaml' }

  let_it_be(:project) do
    files = { devfile_path => example_devfile }
    create(:project, :public, :in_group, :custom_repo, path: 'test-project', files: files, namespace: group)
  end

  let_it_be(:agent) do
    create(:ee_cluster_agent, :with_existing_workspaces_agent_config, project: project, created_by_user: user)
  end

  let_it_be(:agent_token) { create(:cluster_agent_token, agent: agent, created_by_user: user) }

  let(:variable_key) { "VAR1" }
  let(:variable_value) { "value 1" }
  let(:workspaces_group_settings_path) { "/groups/#{group.name}/-/settings/workspaces" }

  before do
    stub_licensed_features(remote_development: true)
    allow(Gitlab::Kas).to receive(:verify_api_request).and_return(true)

    # rubocop:disable RSpec/AnyInstanceOf -- It's NOT the next instance...
    allow_any_instance_of(Gitlab::Auth::AuthFinders)
      .to receive(:cluster_agent_token_from_authorization_token) { agent_token }
    # rubocop:enable RSpec/AnyInstanceOf

    sign_in(user)
    wait_for_requests
  end

  shared_examples 'creates a workspace' do
    it 'creates a workspace' do
      # Tips:
      # use live_debug to pause when WEBDRIVER_HEADLESS=0
      # live_debug

      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542

      # ENABLE AGENT FOR GROUP
      enable_agent_for_group(agent_name: agent.name, group_name: group.name)

      # NAVIGATE TO WORKSPACES PAGE
      visit remote_development_workspaces_path
      wait_for_requests

      # CREATE WORKSPACE

      click_link 'New workspace', match: :first
      click_button 'Select a project'
      find_by_testid("listbox-item-#{project.full_path}").click
      wait_for_requests
      # noinspection RubyMismatchedArgumentType -- Rubymine is finding the wrong `select`
      select agent.name, from: 'Cluster agent'
      # this field should be auto-fill when selecting agent
      expect(page).to have_field(
        'Workspace automatically terminates after',
        with: agent.workspaces_agent_config.default_max_hours_before_termination
      )
      fill_in 'Workspace automatically terminates after', with: '20'
      click_button 'Add variable'
      fill_in 'Variable Key', with: variable_key
      fill_in 'Variable Value', with: variable_value
      click_button 'Create workspace'

      # We look for the project GID because that's all we know about the workspace at this point. For the new UI,
      # we will have to either expose this as a field on the new workspaces UI, or else come up
      # with some more clever finder to assert on the workspace showing up in the list after a refresh.
      page.find('td', text: project.name_with_namespace)

      # GET NAME AND NAMESPACE OF NEW WORKSPACE
      workspaces = RemoteDevelopment::Workspace.all.to_a
      expect(workspaces.length).to eq(1)
      workspace = workspaces[0]

      # ASSERT ON NEW WORKSPACE IN LIST
      page.find('td', text: workspace.name)

      # ASSERT WORKSPACE STATE BEFORE POLLING NEW STATES
      expect_workspace_state_indicator('Creating')

      # ASSERT TERMINATE BUTTON IS AVAILABLE
      expect(page).to have_button('Terminate')

      additional_args_for_expected_config_to_apply =
        build_additional_args_for_expected_config_to_apply(
          network_policy_enabled: true,
          dns_zone: agent.workspaces_agent_config.dns_zone,
          namespace_path: group.path,
          project_name: project.path
        )

      # SIMULATE FIRST POLL FROM AGENTK TO PICK UP NEW WORKSPACE
      simulate_first_poll(
        workspace: workspace.reload,
        **additional_args_for_expected_config_to_apply
      ) do |workspace_agent_infos:, update_type:|
        simulate_agentk_reconcile_post(
          agent_token: agent_token,
          workspace_agent_infos: workspace_agent_infos,
          update_type: update_type
        )
      end

      # SIMULATE SECOND POLL FROM AGENTK TO UPDATE WORKSPACE TO RUNNING STATE
      simulate_second_poll(workspace: workspace.reload) do |workspace_agent_infos:, update_type:|
        simulate_agentk_reconcile_post(
          agent_token: agent_token,
          workspace_agent_infos: workspace_agent_infos,
          update_type: update_type
        )
      end

      # ASSERT WORKSPACE SHOWS RUNNING STATE IN UI AND UPDATES URL
      expect_workspace_state_indicator(RemoteDevelopment::WorkspaceOperations::States::RUNNING)
      expect(page).to have_selector('a', text: workspace.url)

      # ASSERT ACTION BUTTONS ARE CORRECT FOR RUNNING STATE
      expect(page).to have_button('Restart')
      expect(page).to have_button('Stop')
      expect(page).to have_button('Terminate')

      click_button 'Stop'

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

      # ASSERT WORKSPACE SHOWS STOPPING STATE IN UI
      expect_workspace_state_indicator(RemoteDevelopment::WorkspaceOperations::States::STOPPING)

      # ASSERT ACTION BUTTONS ARE CORRECT FOR STOPPING STATE
      # TODO: What other buttons are there?
      expect(page).to have_button('Terminate')

      # SIMULATE FOURTH POLL FROM AGENTK TO UPDATE WORKSPACE TO STOPPED STATE
      simulate_fourth_poll(workspace: workspace.reload) do |workspace_agent_infos:, update_type:|
        simulate_agentk_reconcile_post(
          agent_token: agent_token,
          workspace_agent_infos: workspace_agent_infos,
          update_type: update_type
        )
      end

      # ASSERT WORKSPACE SHOWS STOPPED STATE IN UI
      expect_workspace_state_indicator(RemoteDevelopment::WorkspaceOperations::States::STOPPED)

      # ASSERT ACTION BUTTONS ARE CORRECT FOR STOPPED STATE
      expect(page).to have_button('Start')
      expect(page).to have_button('Terminate')

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

    def expect_workspace_state_indicator(state)
      indicator = find_by_testid('workspace-state-indicator')

      expect(indicator).to have_text(state)
    end

    def simulate_agentk_reconcile_post(agent_token:, workspace_agent_infos:, update_type:)
      post_params = {
        workspace_agent_infos: workspace_agent_infos,
        update_type: update_type
      }

      reconcile_url = capybara_url(
        api('/internal/kubernetes/modules/remote_development/reconcile', personal_access_token: agent_token)
      )

      # Note: HTTParty doesn't handle empty arrays right, so we have to be explicit with content type and send JSON.
      #       See https://github.com/jnunemaker/httparty/issues/494
      reconcile_post_response = HTTParty.post(
        reconcile_url,
        headers: { 'Content-Type' => 'application/json' },
        body: post_params.compact.to_json
      )

      expect(reconcile_post_response.code).to eq(HTTP::Status::CREATED)

      Gitlab::Json.parse(reconcile_post_response.body).deep_symbolize_keys
    end
  end

  context 'when creating a workspace' do
    it_behaves_like 'creates a workspace'
  end
end
