# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Output::ResponsePayloadBuilder, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:update_types) { RemoteDevelopment::WorkspaceOperations::Reconcile::UpdateTypes }
  let(:logger) { instance_double(Logger) }
  let(:desired_state) { RemoteDevelopment::WorkspaceOperations::States::RUNNING }
  let(:actual_state) { RemoteDevelopment::WorkspaceOperations::States::STOPPED }
  let(:processed_devfile_yaml) { example_processed_devfile_yaml }
  let(:force_include_all_resources) { false }
  let(:image_pull_secrets) { [{ name: "secret-name", namespace: "secret-namespace" }] }
  let(:current_desired_config_generator_version) do
    RemoteDevelopment::WorkspaceOperations::DesiredConfigGeneratorVersion::VERSION_3
  end

  let(:agent_config) do
    instance_double(
      "RemoteDevelopment::WorkspacesAgentConfig", # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
      image_pull_secrets: image_pull_secrets
    )
  end

  let(:workspace) do
    instance_double(
      "RemoteDevelopment::Workspace", # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
      id: 1,
      name: "workspace",
      namespace: "namespace",
      deployment_resource_version: "1",
      desired_state: desired_state,
      actual_state: actual_state,
      processed_devfile: processed_devfile_yaml,
      desired_config_generator_version: desired_config_generator_version,
      force_include_all_resources: force_include_all_resources,
      workspaces_agent_config: agent_config
    )
  end

  let(:settings) do
    {
      full_reconciliation_interval_seconds: 3600,
      partial_reconciliation_interval_seconds: 10
    }
  end

  let(:context) do
    {
      update_type: update_type,
      workspaces_to_be_returned: [workspace],
      settings: settings,
      logger: logger
    }
  end

  # NOTE: We are setting `expected_include_all_resources` into our fake `generated_config_to_apply` which is mocked to
  #       be returned from DesiredConfigGenerator. This allows us to perform assertions on the expected passed/returned
  #       value of `include_all_resources` using simple `let` statements, and avoid having to write complex mocks.
  let(:generated_config_to_apply) do
    [
      {
        include_all_resources: expected_include_all_resources,
        some_other_key: 1
      }
    ]
  end

  let(:expected_generated_config_to_apply) { generated_config_to_apply }

  let(:expected_returned_workspace_rails_infos) do
    config_to_apply_yaml_stream = expected_generated_config_to_apply&.map do |resource|
      YAML.dump(resource.deep_stringify_keys)
    end&.join

    [
      {
        name: workspace.name,
        namespace: workspace.namespace,
        deployment_resource_version: workspace.deployment_resource_version,
        desired_state: desired_state,
        actual_state: actual_state,
        image_pull_secrets: image_pull_secrets,
        config_to_apply: config_to_apply_yaml_stream || ""
      }
    ]
  end

  let(:expected_returned_value) do
    context.merge(
      response_payload: {
        workspace_rails_infos: expected_returned_workspace_rails_infos,
        settings: settings
      },
      observability_for_rails_infos: {
        workspace.name => {
          config_to_apply_resources_included: expected_workspace_resources_included_type
        }
      }
    )
  end

  let(:expected_workspace_resources_included_type) do
    described_class::ALL_RESOURCES_INCLUDED
  end

  subject(:returned_value) do
    described_class.build(context)
  end

  before do
    allow(workspace)
      .to receive_messages(
        desired_state_updated_more_recently_than_last_response_to_agent?:
          desired_state_updated_more_recently_than_last_response_to_agent,
        actual_state_updated_more_recently_than_last_response_to_agent?:
          actual_state_updated_more_recently_than_last_response_to_agent,
        desired_state_terminated_and_actual_state_not_terminated?:
          desired_state_terminated_and_actual_state_not_terminated
      )
  end

  context "when workspace.desired_config_generator_version is current version" do
    let(:desired_config_generator_version) { current_desired_config_generator_version }

    before do
      allow(RemoteDevelopment::WorkspaceOperations::Reconcile::Output::DesiredConfigGenerator)
        .to(receive(:generate_desired_config))
        .with(hash_including(include_all_resources: expected_include_all_resources)) { generated_config_to_apply }
    end

    context "when update_type is FULL" do
      let(:desired_state_updated_more_recently_than_last_response_to_agent) { false }
      let(:actual_state_updated_more_recently_than_last_response_to_agent) { false }
      let(:desired_state_terminated_and_actual_state_not_terminated) { false }
      let(:update_type) { RemoteDevelopment::WorkspaceOperations::Reconcile::UpdateTypes::FULL }
      let(:expected_include_all_resources) { true }

      it "includes config_to_apply with all resources included" do
        expect(returned_value).to eq(expected_returned_value)
      end

      context "when config_to_apply contains multiple resources" do
        let(:generated_config_to_apply) do
          [
            {
              a: {
                z: 1,
                a: 1
              }
            },
            {
              b: 2
            }
          ]
        end

        let(:expected_generated_config_to_apply) do
          [
            {
              a: {
                a: 1,
                z: 1
              }
            },
            {
              b: 2
            }
          ]
        end

        it "includes all resources with hashes deep sorted" do
          expect(returned_value).to eq(expected_returned_value)
          returned_value[:response_payload][:workspace_rails_infos].first[:config_to_apply]
          returned_value => {
            response_payload: {
              workspace_rails_infos: [
                {
                  config_to_apply: config_to_apply_yaml_stream
                },
              ]
            }
          }
          loaded_multiple_docs = YAML.load_stream(config_to_apply_yaml_stream)
          expect(loaded_multiple_docs.size).to eq(expected_generated_config_to_apply.size)
        end
      end
    end

    context "when update_type is PARTIAL" do
      let(:update_type) { RemoteDevelopment::WorkspaceOperations::Reconcile::UpdateTypes::PARTIAL }

      using RSpec::Parameterized::TableSyntax

      where(
        :force_include_all_resources,
        :desired_state_updated_more_recently_than_last_response_to_agent,
        :actual_state_updated_more_recently_than_last_response_to_agent,
        :desired_state_terminated_and_actual_state_not_terminated,
        :expected_include_all_resources,
        :expected_workspace_resources_included_type,
        :expect_config_to_apply_to_be_included
      ) do
        # @formatter:off - Turn off RubyMine autoformatting
        true  | true  | false | false | true  | described_class::ALL_RESOURCES_INCLUDED     | true
        true  | false | false | false | true  | described_class::ALL_RESOURCES_INCLUDED     | true
        false | true  | false | false | false | described_class::PARTIAL_RESOURCES_INCLUDED | true
        false | false | false | false | false | described_class::NO_RESOURCES_INCLUDED      | false
        false | false | false | true  | false | described_class::PARTIAL_RESOURCES_INCLUDED | true
        true  | true  | true  | false | true  | described_class::ALL_RESOURCES_INCLUDED     | true
        true  | false | true  | false | true  | described_class::ALL_RESOURCES_INCLUDED     | true
        false | true  | true  | false | true  | described_class::ALL_RESOURCES_INCLUDED     | true
        false | false | true  | false | true  | described_class::ALL_RESOURCES_INCLUDED     | true
        # @formatter:on
      end

      with_them do
        let(:generated_config_to_apply) { nil } unless params[:expect_config_to_apply_to_be_included]

        it { expect(returned_value).to eq(expected_returned_value) }
      end
    end
  end

  context "when workspace.desired_config_generator_version is a previous version" do
    let(:previous_desired_config_generator_version) { 2 }

    let(:desired_config_generator_version) { previous_desired_config_generator_version }
    let(:update_type) { update_types::FULL }
    let(:desired_state_updated_more_recently_than_last_response_to_agent) { false }
    let(:actual_state_updated_more_recently_than_last_response_to_agent) { false }
    let(:desired_state_terminated_and_actual_state_not_terminated) { false }
    let(:expected_include_all_resources) { true }

    before do
      stub_const(
        "RemoteDevelopment::WorkspaceOperations::Reconcile::Output::DesiredConfigGeneratorV2",
        Class.new do
          # @param [Object] _
          # @return [Hash]
          def self.generate_desired_config(_)
            {}
          end
        end
      )
    end

    it "includes config_to_apply with all resources included" do
      # noinspection RubyResolve -- This constant is stubbed
      allow(RemoteDevelopment::WorkspaceOperations::Reconcile::Output::DesiredConfigGeneratorV2)
        .to(receive(:generate_desired_config)) { generated_config_to_apply }

      expect(returned_value).to eq(expected_returned_value)
    end
  end
end
