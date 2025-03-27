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
  # NOTE: The generated_config_to_apply can include string keys because users can provide labels and annotations in
  #       their agent configuration which we use in the DesiredConfigGenerator which is being mocked here.
  let(:single_resource) do
    [
      {
        include_all_resources: expected_include_all_resources,
        some_other_key: 1,
        "some_other_string_key" => 2
      }
    ]
  end

  let(:multiple_resources) do
    [
      {
        a: 1
      },
      {
        b: 2
      },
      {
        c: 3
      }
    ]
  end

  let(:no_resource) { nil }

  let(:generated_config_to_apply) do
    case generated_config_to_apply_type
    when :single_resource
      single_resource
    when :multiple_resources
      multiple_resources
    when :no_resource
      nil
    end
  end

  let(:expected_returned_workspace_rails_infos) do
    config_to_apply_yaml_stream = generated_config_to_apply&.map do |resource|
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

    using RSpec::Parameterized::TableSyntax

    # rubocop:disable Layout/LineLength -- Required for formatting of table
    where(
      :update_type,
      :force_include_all_resources,
      :desired_state_updated_more_recently_than_last_response_to_agent,
      :desired_state_terminated_and_actual_state_not_terminated,
      :generated_config_to_apply_type,
      :expected_include_all_resources,
      :expected_workspace_resources_included_type
    ) do
      update_types::FULL    | false  | false | false | :multiple_resources | true | described_class::ALL_RESOURCES_INCLUDED
      update_types::FULL    | true   | true  | true  | :single_resource | true | described_class::ALL_RESOURCES_INCLUDED
      update_types::FULL    | true   | true  | false | :single_resource | true | described_class::ALL_RESOURCES_INCLUDED
      update_types::FULL    | true   | false | true  | :single_resource | true | described_class::ALL_RESOURCES_INCLUDED
      update_types::FULL    | true   | false | false | :single_resource | true | described_class::ALL_RESOURCES_INCLUDED
      update_types::FULL    | false  | true  | true  | :single_resource | true | described_class::ALL_RESOURCES_INCLUDED
      update_types::FULL    | false  | true  | false | :single_resource | true | described_class::ALL_RESOURCES_INCLUDED
      update_types::FULL    | false  | false | true  | :single_resource | true | described_class::ALL_RESOURCES_INCLUDED
      update_types::FULL    | false  | false | false | :single_resource | true | described_class::ALL_RESOURCES_INCLUDED
      update_types::PARTIAL | true   | true  | true  | :single_resource | true  | described_class::ALL_RESOURCES_INCLUDED
      update_types::PARTIAL | true   | true  | false | :single_resource | true  | described_class::ALL_RESOURCES_INCLUDED
      update_types::PARTIAL | true   | false | true  | :single_resource | true  | described_class::ALL_RESOURCES_INCLUDED
      update_types::PARTIAL | true   | false | false | :single_resource | true  | described_class::ALL_RESOURCES_INCLUDED
      update_types::PARTIAL | false  | true  | true  | :single_resource | false | described_class::PARTIAL_RESOURCES_INCLUDED
      update_types::PARTIAL | false  | true  | false | :single_resource | false | described_class::PARTIAL_RESOURCES_INCLUDED
      update_types::PARTIAL | false  | false | true  | :single_resource | false | described_class::PARTIAL_RESOURCES_INCLUDED
      update_types::PARTIAL | false  | false | false | :no_resource | false | described_class::NO_RESOURCES_INCLUDED
    end
    # rubocop:enable Layout/LineLength

    with_them do
      it "expected resources are included in config_to_apply" do
        expect(returned_value).to eq(expected_returned_value)
      end
    end
  end

  # rubocop:disable RSpec/MultipleMemoizedHelpers -- needed helpers for multiple cases
  context "when workspace.desired_config_generator_version is a previous version" do
    let(:previous_desired_config_generator_version) { 2 }
    let(:generated_config_to_apply_type) { :single_resource }
    let(:desired_config_generator_version) { previous_desired_config_generator_version }
    let(:update_type) { update_types::FULL }
    let(:desired_state_updated_more_recently_than_last_response_to_agent) { false }
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
  # rubocop:enable RSpec/MultipleMemoizedHelpers
end
