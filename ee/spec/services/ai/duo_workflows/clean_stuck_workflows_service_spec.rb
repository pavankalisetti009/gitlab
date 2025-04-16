# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::CleanStuckWorkflowsService, feature_category: :duo_workflow do
  describe '#execute' do
    let!(:initialized_workflow) { create(:duo_workflows_workflow, status: 0) }
    let!(:recently_running_workflow) { create(:duo_workflows_workflow, status: 1) }
    let!(:stale_running_workflow) { create(:duo_workflows_workflow, status: 1, updated_at: 2.days.ago) }

    it 'marks stale running workflows as failed' do
      described_class.new.execute

      expect(initialized_workflow.reload.human_status_name).to eq("created")
      expect(recently_running_workflow.reload.human_status_name).to eq("running")
      expect(stale_running_workflow.reload.human_status_name).to eq("failed")
    end
  end
end
