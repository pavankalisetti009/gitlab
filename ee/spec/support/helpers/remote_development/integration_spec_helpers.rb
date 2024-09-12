# frozen_string_literal: true

module RemoteDevelopment
  module IntegrationSpecHelpers
    def enable_agent_for_group(agent_name:, group_name:)
      workspaces_group_settings_path = "/groups/#{group_name}/-/settings/workspaces"
      gitlab_badge_selector = '.gl-badge-content'
      visit workspaces_group_settings_path
      wait_for_requests

      # enable agent for group
      click_link 'All agents'
      expect(page).to have_content agent_name
      first_agent_row_selector = 'tbody tr:first-child'
      expect(page).not_to have_selector(gitlab_badge_selector, text: 'Allowed')
      within first_agent_row_selector do
        click_button 'Allow'
        wait_for_requests
      end
      click_button 'Allow agent'
      expect(page).to have_selector(gitlab_badge_selector, text: 'Allowed')
    end

    def build_additional_args_for_expected_config_to_apply(
      network_policy_enabled:,
      dns_zone:,
      namespace_path: workspace_project_namespace.full_path,
      project_name: workspace_project_name
    )
      {
        dns_zone: dns_zone,
        namespace_path: namespace_path,
        project_name: project_name,
        include_network_policy: network_policy_enabled
      }
    end

    def simulate_first_poll(
      workspace:,
      **additional_args_for_create_config_to_apply,
      &simulate_agentk_reconcile_post_block
    )
      # SIMULATE FIRST POLL REQUEST FROM AGENTK TO GET NEW WORKSPACE

      update_type = "partial"
      response_json = simulate_agentk_reconcile_post_block.yield(
        workspace_agent_infos: [],
        update_type: update_type
      )

      # ASSERT ON RESPONSE TO FIRST POLL REQUEST CONTAINING NEW WORKSPACE

      infos = response_json.fetch(:workspace_rails_infos)
      expect(infos.length).to eq(1)
      info = infos.first

      expect(info.fetch(:name)).to eq(workspace.name)
      expect(info.fetch(:namespace)).to eq(workspace.namespace)
      expect(info.fetch(:desired_state)).to eq(RemoteDevelopment::WorkspaceOperations::States::RUNNING)
      expect(info.fetch(:actual_state)).to eq(RemoteDevelopment::WorkspaceOperations::States::CREATION_REQUESTED)
      expect(info.fetch(:deployment_resource_version)).to be_nil

      expected_config_to_apply = create_config_to_apply(
        workspace: workspace,
        started: true,
        include_all_resources: true,
        **additional_args_for_create_config_to_apply
      )

      config_to_apply = info.fetch(:config_to_apply)
      expect(config_to_apply).to eq(expected_config_to_apply)
    end

    def simulate_second_poll(
      workspace:,
      &simulate_agentk_reconcile_post_block
    )
      # SIMULATE SECOND POLL REQUEST FROM AGENTK TO UPDATE WORKSPACE TO RUNNING STATE

      resource_version = '1'
      workspace_agent_info = create_workspace_agent_info_hash(
        workspace: workspace,
        previous_actual_state: RemoteDevelopment::WorkspaceOperations::States::STARTING,
        current_actual_state: RemoteDevelopment::WorkspaceOperations::States::RUNNING,
        workspace_exists: false,
        resource_version: resource_version
      )

      update_type = "partial"
      response_json = simulate_agentk_reconcile_post_block.yield(
        workspace_agent_infos: [workspace_agent_info],
        update_type: update_type
      )

      # ASSERT ON RESPONSE TO SECOND POLL REQUEST

      infos = response_json.fetch(:workspace_rails_infos)
      expect(infos.length).to eq(1)
      info = infos.first

      expect(info.fetch(:name)).to eq(workspace.name)
      expect(info.fetch(:namespace)).to eq(workspace.namespace)
      expect(info.fetch(:desired_state)).to eq(RemoteDevelopment::WorkspaceOperations::States::RUNNING)
      expect(info.fetch(:actual_state)).to eq(RemoteDevelopment::WorkspaceOperations::States::RUNNING)
      expect(info.fetch(:deployment_resource_version)).to eq(resource_version)
      expect(info.fetch(:config_to_apply)).to be_nil
    end

    def simulate_third_poll(
      workspace:,
      **additional_args_for_create_config_to_apply,
      &simulate_agentk_reconcile_post_block
    )
      # SIMULATE THIRD POLL REQUEST FROM AGENTK TO UPDATE WORKSPACE TO STOPPING STATE

      resource_version = '1'
      workspace_agent_info = create_workspace_agent_info_hash(
        workspace: workspace,
        previous_actual_state: RemoteDevelopment::WorkspaceOperations::States::RUNNING,
        current_actual_state: RemoteDevelopment::WorkspaceOperations::States::STOPPING,
        workspace_exists: true,
        resource_version: resource_version
      )

      update_type = "partial"
      response_json = simulate_agentk_reconcile_post_block.yield(
        workspace_agent_infos: [workspace_agent_info],
        update_type: update_type
      )

      # ASSERT ON RESPONSE TO THIRD POLL REQUEST

      infos = response_json.fetch(:workspace_rails_infos)
      expect(infos.length).to eq(1)
      info = infos.first

      expect(info.fetch(:name)).to eq(workspace.name)
      expect(info.fetch(:namespace)).to eq(workspace.namespace)
      expect(info.fetch(:desired_state)).to eq(RemoteDevelopment::WorkspaceOperations::States::STOPPED)
      expect(info.fetch(:actual_state)).to eq(RemoteDevelopment::WorkspaceOperations::States::STOPPING)
      expect(info.fetch(:deployment_resource_version)).to eq(resource_version)

      expected_config_to_apply = create_config_to_apply(
        workspace: workspace,
        started: false,
        **additional_args_for_create_config_to_apply
      )

      config_to_apply = info.fetch(:config_to_apply)
      expect(config_to_apply).to eq(expected_config_to_apply)
    end

    def simulate_fourth_poll(
      workspace:,
      &simulate_agentk_reconcile_post_block
    )
      # SIMULATE FOURTH POLL REQUEST FROM AGENTK TO UPDATE WORKSPACE TO STOPPED STATE

      resource_version = '2'
      workspace_agent_info = create_workspace_agent_info_hash(
        workspace: workspace,
        previous_actual_state: RemoteDevelopment::WorkspaceOperations::States::STOPPING,
        current_actual_state: RemoteDevelopment::WorkspaceOperations::States::STOPPED,
        workspace_exists: true,
        resource_version: resource_version
      )

      update_type = "partial"
      response_json = simulate_agentk_reconcile_post_block.yield(
        workspace_agent_infos: [workspace_agent_info],
        update_type: update_type
      )

      # ASSERT ON RESPONSE TO FOURTH POLL REQUEST

      infos = response_json.fetch(:workspace_rails_infos)
      expect(infos.length).to eq(1)
      info = infos.first

      expect(info.fetch(:name)).to eq(workspace.name)
      expect(info.fetch(:namespace)).to eq(workspace.namespace)
      expect(info.fetch(:desired_state)).to eq(RemoteDevelopment::WorkspaceOperations::States::STOPPED)
      expect(info.fetch(:actual_state)).to eq(RemoteDevelopment::WorkspaceOperations::States::STOPPED)
      expect(info.fetch(:deployment_resource_version)).to eq(resource_version)
      expect(info.fetch(:config_to_apply)).to be_nil
    end

    def simulate_fifth_poll(&simulate_agentk_reconcile_post_block)
      # SIMULATE FIFTH POLL FROM AGENTK FOR PARTIAL RECONCILE TO SHOW NO RAILS_INFOS ARE SENT

      update_type = "partial"
      response_json = simulate_agentk_reconcile_post_block.yield(
        workspace_agent_infos: [],
        update_type: update_type
      )

      # ASSERT ON RESPONSE TO FIFTH POLL REQUEST

      infos = response_json.fetch(:workspace_rails_infos)
      expect(infos.length).to eq(0)
    end

    def simulate_sixth_poll(
      workspace:,
      **additional_args_for_create_config_to_apply,
      &simulate_agentk_reconcile_post_block
    )
      # SIMULATE FIFTH POLL FROM AGENTK FOR FULL RECONCILE TO SHOW ALL WORKSPACES ARE SENT IN RAILS_INFOS

      resource_version = '2'
      workspace_agent_info = create_workspace_agent_info_hash(
        workspace: workspace,
        previous_actual_state: RemoteDevelopment::WorkspaceOperations::States::STOPPED,
        current_actual_state: RemoteDevelopment::WorkspaceOperations::States::STOPPED,
        workspace_exists: true,
        resource_version: resource_version
      )

      update_type = "full"
      response_json = simulate_agentk_reconcile_post_block.yield(
        workspace_agent_infos: [workspace_agent_info],
        update_type: update_type
      )

      # ASSERT ON RESPONSE TO SIXTH POLL REQUEST CONTAINING NEW WORKSPACE

      infos = response_json.fetch(:workspace_rails_infos)
      expect(infos.length).to eq(1)
      info = infos.first

      expect(info.fetch(:name)).to eq(workspace.name)
      expect(info.fetch(:deployment_resource_version)).to eq(resource_version)

      expected_config_to_apply = create_config_to_apply(
        workspace: workspace,
        started: false,
        include_all_resources: true,
        **additional_args_for_create_config_to_apply
      )

      config_to_apply = info.fetch(:config_to_apply)
      expect(config_to_apply).to eq(expected_config_to_apply)
    end
  end
end
