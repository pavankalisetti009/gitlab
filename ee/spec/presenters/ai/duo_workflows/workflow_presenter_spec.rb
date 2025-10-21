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
    it 'returns the first checkpoint of the workflow' do
      first_checkpoint = instance_double(::Ai::DuoWorkflows::Checkpoint)
      checkpoints = [first_checkpoint, instance_double(::Ai::DuoWorkflows::Checkpoint)]

      allow(workflow).to receive(:checkpoints).and_return(checkpoints)

      expect(presenter.first_checkpoint).to eq(first_checkpoint)
    end

    it 'returns nil when there are no checkpoints' do
      allow(workflow).to receive(:checkpoints).and_return([])

      expect(presenter.first_checkpoint).to be_nil
    end
  end

  describe 'latest_checkpoint' do
    it 'returns the last checkpoint of the workflow' do
      latest_checkpoint = instance_double(::Ai::DuoWorkflows::Checkpoint)
      checkpoints = [instance_double(::Ai::DuoWorkflows::Checkpoint), latest_checkpoint]

      allow(workflow).to receive(:checkpoints).and_return(checkpoints)

      expect(presenter.latest_checkpoint).to eq(latest_checkpoint)
    end

    it 'returns nil when there are no checkpoints' do
      allow(workflow).to receive(:checkpoints).and_return([])

      expect(presenter.latest_checkpoint).to be_nil
    end
  end
end
