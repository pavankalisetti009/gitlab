# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Output::ScriptsConfigmapAppender, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:files) { RemoteDevelopment::Files }
  let(:annotations) { { a: "1" } }
  let(:labels) { { b: "2" } }
  let(:name) { "workspacename-scripts-configmap" }
  let(:namespace) { "namespace" }
  let(:processed_devfile) { example_processed_devfile }
  let(:devfile_commands) { processed_devfile.fetch(:commands) }
  let(:devfile_events) { processed_devfile.fetch(:events) }
  let(:expected_postart_commands_script) do
    <<~SCRIPT
      #!/bin/sh
      echo "$(date -Iseconds): Running #{reconcile_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/gl-start-sshd-command..."
      #{reconcile_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/gl-start-sshd-command || true
      echo "$(date -Iseconds): Running #{reconcile_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/gl-init-tools-command..."
      #{reconcile_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/gl-init-tools-command || true
      echo "$(date -Iseconds): Running #{reconcile_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/gl-sleep-until-container-is-running-command..."
      #{reconcile_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/gl-sleep-until-container-is-running-command || true
    SCRIPT
  end

  let(:main_component_updater_sleep_until_container_is_running_script) do
    format(
      files::MAIN_COMPONENT_UPDATER_SLEEP_UNTIL_CONTAINER_IS_RUNNING_SCRIPT,
      workspace_reconciled_actual_state_file_path:
        workspace_operations_constants_module::WORKSPACE_RECONCILED_ACTUAL_STATE_FILE_PATH
    )
  end

  subject(:updated_desired_config) do
    # Make a fake desired config with one existing fake element, to prove we are appending
    desired_config = [
      {}
    ]

    described_class.append(
      desired_config: desired_config,
      name: name,
      namespace: namespace,
      labels: labels,
      annotations: annotations,
      devfile_commands: devfile_commands,
      devfile_events: devfile_events
    )

    desired_config
  end

  it "appends ConfigMap to desired_config" do
    expect(updated_desired_config.length).to eq(2)

    updated_desired_config => [
      {}, # existing fake element
      {
        apiVersion: api_version,
        metadata: {
          name: configmap_name
        },
        data: data
      },
    ]

    expect(api_version).to eq("v1")
    expect(configmap_name).to eq(name)
    expect(data).to eq(
      "gl-init-tools-command": files::MAIN_COMPONENT_UPDATER_INIT_TOOLS_SCRIPT,
      reconcile_constants_module::RUN_POSTSTART_COMMANDS_SCRIPT_NAME.to_sym =>
        expected_postart_commands_script,
      "gl-sleep-until-container-is-running-command":
        main_component_updater_sleep_until_container_is_running_script,
      "gl-start-sshd-command": files::MAIN_COMPONENT_UPDATER_START_SSHD_SCRIPT
    )
  end
end
