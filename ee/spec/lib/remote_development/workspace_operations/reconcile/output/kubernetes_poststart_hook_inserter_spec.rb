# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Output::KubernetesPoststartHookInserter, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:processed_devfile) { example_processed_devfile }
  let(:devfile_commands) { processed_devfile.fetch(:commands) }
  let(:devfile_events) { processed_devfile.fetch(:events) }
  let(:input_containers) do
    deployment = create_deployment(include_scripts_resources: false)
    deployment => {
      spec: {
        template: {
          spec: {
            containers: Array => containers
          }
        }
      }
    }
    containers
  end

  let(:expected_containers) do
    deployment = create_deployment(include_scripts_resources: true)
    deployment => {
      spec: {
        template: {
          spec: {
            containers: Array => containers
          }
        }
      }
    }
    containers
  end

  subject(:invoke_insert) do
    described_class.insert(
      # pass input containers without resources for scripts added, then assert they get added by the described_class
      containers: input_containers,
      devfile_commands: devfile_commands,
      devfile_events: devfile_events
    )
  end

  it "has valid fixtures with no lifecycle in any input_containers" do
    expect(input_containers.any? { |c| c[:lifecycle] }).to be false
  end

  it "inserts postStart lifecycle hooks", :unlimited_max_formatted_output_length do
    invoke_insert

    expected_containers => [
      *_,
      {
        lifecycle: Hash => first_container_expected_lifecycle_hooks
      },
      *_
    ]

    input_containers => [
      *_,
      {
        lifecycle: Hash => first_container_updated_lifecycle_hooks
      },
      *_
    ]

    expect(first_container_updated_lifecycle_hooks).to eq(first_container_expected_lifecycle_hooks)
  end

  private

  # @param [Boolean] include_scripts_resources
  # @return [Hash]
  def create_deployment(include_scripts_resources:)
    workspace_deployment(
      workspace_name: "name",
      workspace_namespace: "namespace",
      include_scripts_resources: include_scripts_resources
    )
  end
end
