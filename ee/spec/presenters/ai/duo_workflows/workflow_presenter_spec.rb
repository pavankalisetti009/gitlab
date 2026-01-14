# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::WorkflowPresenter, feature_category: :duo_agent_platform do
  let(:workflow) { build_stubbed(:duo_workflows_workflow) }
  let_it_be(:user) { build_stubbed(:user) }

  subject(:presenter) { described_class.new(workflow, current_user: user) }

  describe 'human_status' do
    it 'returns the human readable status' do
      expect(presenter.human_status).to eq("created")
    end
  end

  describe 'mcp_enabled' do
    let_it_be(:ai_settings) { build_stubbed(:namespace_ai_settings, duo_workflow_mcp_enabled: true) }

    it 'returns the mcp_enabled status from the root ancestor' do
      root_ancestor = instance_double(Group, duo_workflow_mcp_enabled: true)
      allow(workflow.project).to receive(:root_ancestor).and_return(root_ancestor)

      expect(presenter.mcp_enabled).to be(true)
    end

    context 'with namespace-level workflow' do
      let(:group) { build_stubbed(:group) }
      let(:workflow) { build_stubbed(:duo_workflows_workflow, namespace: group, project: nil) }

      it { expect(presenter.mcp_enabled).to be(false) }

      context 'when duo_workflow_mcp_enabled is enabled on root ancestor' do
        before do
          root_ancestor = instance_double(Group, duo_workflow_mcp_enabled: true)
          allow(workflow.namespace).to receive(:root_ancestor).and_return(root_ancestor)
        end

        it { expect(presenter.mcp_enabled).to be(true) }
      end
    end
  end

  describe 'agent_privileges_names' do
    it 'returns the agent privileges names' do
      allow(workflow).to receive(:agent_privileges).and_return([
        ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES
      ])

      expect(presenter.agent_privileges_names).to eq(['read_write_files'])
    end
  end

  describe 'pre_approved_agent_privileges_names' do
    it 'returns the pre-approved agent privileges names' do
      allow(workflow).to receive(:pre_approved_agent_privileges).and_return([
        ::Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES,
        ::Ai::DuoWorkflows::Workflow::AgentPrivileges::RUN_COMMANDS
      ])

      expect(presenter.pre_approved_agent_privileges_names).to eq(%w[read_write_files run_commands])
    end
  end

  describe 'first_checkpoint' do
    it 'returns the earliest checkpoint of the workflow' do
      earliest_checkpoint = instance_double(::Ai::DuoWorkflows::Checkpoint)
      checkpoints_relation = double

      allow(workflow).to receive(:checkpoints).and_return(checkpoints_relation)
      allow(checkpoints_relation).to receive(:earliest).and_return(earliest_checkpoint)

      expect(presenter.first_checkpoint).to eq(earliest_checkpoint)
    end

    it 'returns nil when there are no checkpoints' do
      checkpoints_relation = double

      allow(workflow).to receive(:checkpoints).and_return(checkpoints_relation)
      allow(checkpoints_relation).to receive(:earliest).and_return(nil)

      expect(presenter.first_checkpoint).to be_nil
    end
  end

  describe 'latest_checkpoint' do
    it 'returns the latest checkpoint of the workflow' do
      latest_checkpoint = instance_double(::Ai::DuoWorkflows::Checkpoint)
      checkpoints_relation = double

      allow(workflow).to receive(:checkpoints).and_return(checkpoints_relation)
      allow(checkpoints_relation).to receive(:latest).and_return(latest_checkpoint)

      expect(presenter.latest_checkpoint).to eq(latest_checkpoint)
    end

    it 'returns nil when there are no checkpoints' do
      checkpoints_relation = double

      allow(workflow).to receive(:checkpoints).and_return(checkpoints_relation)
      allow(checkpoints_relation).to receive(:latest).and_return(nil)

      expect(presenter.latest_checkpoint).to be_nil
    end
  end

  describe 'agent_name' do
    context 'when workflow uses a custom catalog agent' do
      it 'returns the catalog item name' do
        catalog_item = instance_double(Ai::Catalog::Item, name: 'Custom Agent')
        catalog_item_version = instance_double(Ai::Catalog::ItemVersion, item: catalog_item)
        allow(workflow).to receive_messages(
          ai_catalog_item_version_id: 123,
          ai_catalog_item_version: catalog_item_version
        )

        expect(presenter.agent_name).to eq('Custom Agent')
      end
    end

    context 'when workflow uses a foundational agent' do
      it 'returns the foundational agent name' do
        allow(workflow).to receive_messages(
          ai_catalog_item_version_id: nil,
          workflow_definition: 'chat'
        )

        expect(presenter.agent_name).to eq('GitLab Duo')
      end
    end

    context 'when workflow has no agent information' do
      it 'returns nil' do
        allow(workflow).to receive_messages(
          ai_catalog_item_version_id: nil,
          workflow_definition: nil
        )

        expect(presenter.agent_name).to be_nil
      end
    end
  end
end
