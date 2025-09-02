# frozen_string_literal: true

require "fast_spec_helper"
require "ffaker"

# rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::CreatorBootstrapper, feature_category: :workspaces do
  include_context "with constant modules"

  let(:workspaces_agent_config) do
    instance_double("RemoteDevelopment::WorkspacesAgentConfig", shared_namespace: shared_namespace)
  end

  let(:agent) do
    instance_double("Clusters::Agent", id: 2, unversioned_latest_workspaces_agent_config: workspaces_agent_config)
  end

  let(:context) do
    {
      params: {
        agent: agent
      }
    }
  end

  let(:expected_random_name) { 'peach-blue-whale-red' }

  subject(:returned_value) do
    described_class.bootstrap(context)
  end

  describe "workspace_name" do
    let(:expected_workspace_name) { "workspace-#{expected_random_name}" }
    let(:shared_namespace) { "" }

    context "when the generated workspace name is unique" do
      it "is set in context" do
        allow(FFaker::Food).to receive(:fruit).and_return("Peach")
        allow(FFaker::AnimalUS).to receive(:common_name).and_return("Blue Whale")
        allow(FFaker::Color).to receive(:name).and_return("Red")

        stub_const("RemoteDevelopment::Workspace", Class.new)
        allow(RemoteDevelopment::Workspace)
          .to receive(:by_names)
                .with("workspace-peach-blue-whale-red")
                .and_return(instance_double("ActiveRecord::Relation", exists?: false))

        expect(returned_value.fetch(:workspace_name)).to eq(expected_workspace_name)
      end
    end

    context "when the generated workspace name is already taken" do
      let(:expected_random_name) { 'pear-bald-eagle-green' }

      it "generates another name" do
        expect(FFaker::Food).to receive(:fruit).and_return("Peach", "Pear")
        expect(FFaker::AnimalUS).to receive(:common_name).and_return("Blue Whale", "Bald Eagle")
        expect(FFaker::Color).to receive(:name).and_return("Red", "Green")

        stub_const("RemoteDevelopment::Workspace", Class.new)
        expect(RemoteDevelopment::Workspace)
          .to receive(:by_names)
                .once
                .with("workspace-peach-blue-whale-red")
                .and_return(instance_double("ActiveRecord::Relation", exists?: true))
                .ordered
        expect(RemoteDevelopment::Workspace)
          .to receive(:by_names)
                .once
                .with("workspace-pear-bald-eagle-green")
                .and_return(instance_double("ActiveRecord::Relation", exists?: false))
                .ordered
        expect(returned_value.fetch(:workspace_name)).to eq(expected_workspace_name)
      end

      context "when the limit of attempts is reached" do
        it "raises an error" do
          expect(FFaker::Food).to receive(:fruit).exactly(30).times.and_return("Peach")
          expect(FFaker::AnimalUS).to receive(:common_name).exactly(30).times.and_return("Blue Whale")
          expect(FFaker::Color).to receive(:name).exactly(30).times.and_return("Red")

          stub_const("RemoteDevelopment::Workspace", Class.new)
          expect(RemoteDevelopment::Workspace)
            .to receive(:by_names)
                  .exactly(30)
                  .times
                  .with("workspace-peach-blue-whale-red")
                  .and_return(instance_double("ActiveRecord::Relation", exists?: true))

          expect { returned_value.fetch(:workspace_name) }
            .to raise_error(/Unable to generate unique workspace name after 30 attempts/)
        end
      end
    end
  end

  describe "workspace_namespace" do
    context "when shared namespace is set to an empty string" do
      let(:shared_namespace) { "" }

      it "is set in context" do
        expect(FFaker::Food).to receive(:fruit).and_return("Peach")
        expect(FFaker::AnimalUS).to receive(:common_name).and_return("Blue Whale")
        expect(FFaker::Color).to receive(:name).and_return("Red")

        stub_const("RemoteDevelopment::Workspace", Class.new)
        allow(RemoteDevelopment::Workspace)
          .to receive(:by_names)
                .with("workspace-peach-blue-whale-red")
                .and_return(instance_double("ActiveRecord::Relation", exists?: false))

        expect(returned_value.fetch(:workspace_namespace))
          .to eq("#{create_constants_module::NAMESPACE_PREFIX}-#{expected_random_name}")
      end
    end

    context "when shared namespace is set to a value" do
      let(:shared_namespace) { "my-shared-namespace" }

      it "is set in context" do
        expect(FFaker::Food).to receive(:fruit).and_return("Peach")
        expect(FFaker::AnimalUS).to receive(:common_name).and_return("Blue Whale")
        expect(FFaker::Color).to receive(:name).and_return("Red")

        stub_const("RemoteDevelopment::Workspace", Class.new)
        allow(RemoteDevelopment::Workspace)
          .to receive(:by_names)
                .with("workspace-peach-blue-whale-red")
                .and_return(instance_double("ActiveRecord::Relation", exists?: false))

        expect(returned_value.fetch(:workspace_namespace)).to eq(shared_namespace)
      end
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubleReference
