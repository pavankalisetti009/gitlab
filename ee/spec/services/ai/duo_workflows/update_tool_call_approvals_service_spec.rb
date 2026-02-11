# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::UpdateToolCallApprovalsService, feature_category: :duo_agent_platform do
  describe '#execute' do
    subject(:result) do
      described_class.new(
        workflow: workflow,
        tool_name: tool_name,
        tool_call_args: tool_call_args,
        current_user: user
      ).execute
    end

    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:user) { create(:user, maintainer_of: project) }

    let(:workflow) { create(:duo_workflows_workflow, project: project, user: user) }
    let(:tool_name) { 'run_command' }
    let(:tool_call_args) { '{"command": "ls -la", "working_dir": "/home"}' }

    context 'when user does not have permission to update workflow' do
      before do
        allow(user).to receive(:can?).with(:update_duo_workflow, workflow).and_return(false)
      end

      it 'returns unauthorized error', :aggregate_failures do
        expect(result.error?).to be true
        expect(result.message).to eq('Can not update workflow')
        expect(result.reason).to eq(:unauthorized)
        expect(workflow.reload.tool_call_approvals).to eq({})
      end
    end

    context 'when user has permission to update workflow' do
      before do
        allow(user).to receive(:can?).with(:update_duo_workflow, workflow).and_return(true)
      end

      it 'acquires a lock and saves workflow', :aggregate_failures do
        expect(workflow).to receive(:with_lock).with('FOR UPDATE NOWAIT').and_yield
        expect(workflow).to receive(:add_tool_call_approval).with(tool_name: tool_name, call_args: tool_call_args)
        expect(workflow).to receive(:save).and_return(true)

        expect(result.success?).to be true
        expect(result.message).to eq('Tool call approvals updated successfully')
        expect(result.payload[:workflow]).to eq(workflow)
      end

      context 'when workflow save fails' do
        let(:errors) { ActiveModel::Errors.new(workflow) }

        before do
          errors.add(:base, 'Validation failed')
          allow(workflow).to receive(:with_lock).with('FOR UPDATE NOWAIT').and_yield
          allow(workflow).to receive(:add_tool_call_approval)
          allow(workflow).to receive_messages(save: false, errors: errors)
        end

        it 'returns error with validation messages', :aggregate_failures do
          expect(result.error?).to be true
          expect(result.message).to include('Failed to update tool_call_approvals')
          expect(result.message).to include('Validation failed')
        end
      end

      context 'when workflow is locked by another process' do
        before do
          allow(workflow).to receive(:with_lock).with('FOR UPDATE NOWAIT')
            .and_raise(ActiveRecord::LockWaitTimeout)
        end

        it 'returns error indicating concurrent update', :aggregate_failures do
          expect(result.error?).to be true
          expect(result.message).to eq('Workflow is currently being updated, please try again')
        end
      end
    end
  end
end
