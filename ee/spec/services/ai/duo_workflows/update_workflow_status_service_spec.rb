# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::UpdateWorkflowStatusService, feature_category: :duo_workflow do
  describe '#execute' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user, maintainer_of: project) }
    let_it_be(:another_user) { create(:user) }
    let(:workflow_initial_status_enum) { 1 }
    let(:workflow) do
      create(:duo_workflows_workflow, project: project, user: user, status: workflow_initial_status_enum)
    end

    context "when feature flag is disabled" do
      before do
        stub_feature_flags(duo_workflow: false)
      end

      it "returns not found", :aggregate_failures do
        result = described_class.new(workflow: workflow, current_user: user, status_event: "finish").execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq("Can not update workflow")
        expect(result[:reason]).to eq(:not_found)
        expect(workflow.reload.human_status_name).to eq("running")
      end
    end

    it "can finish a workflow", :aggregate_failures do
      checkpoint = create(:duo_workflows_checkpoint, workflow: workflow, project: workflow.project)
      expect(GraphqlTriggers).to receive(:workflow_events_updated).with(checkpoint).and_return(1)

      result = described_class.new(workflow: workflow, current_user: user, status_event: "finish").execute

      expect(result[:status]).to eq(:success)
      expect(result[:message]).to eq("Workflow status updated")
      expect(workflow.reload.human_status_name).to eq("finished")
    end

    it "can drop a workflow", :aggregate_failures do
      result = described_class.new(workflow: workflow, current_user: user, status_event: "drop").execute

      expect(result[:status]).to eq(:success)
      expect(result[:message]).to eq("Workflow status updated")
      expect(workflow.reload.human_status_name).to eq("failed")
    end

    context "when initial status is created" do
      let(:workflow_initial_status_enum) { 0 } # status created

      it "can start a workflow", :aggregate_failures do
        result = described_class.new(workflow: workflow, current_user: user, status_event: "start").execute

        expect(result[:status]).to eq(:success)
        expect(result[:message]).to eq("Workflow status updated")
        expect(workflow.reload.human_status_name).to eq("running")
      end
    end

    it "does not update to not allowed status", :aggregate_failures do
      result = described_class.new(workflow: workflow, current_user: user, status_event: "pause").execute

      expect(result[:status]).to eq(:error)
      expect(result[:message]).to eq("Can not update workflow status, unsupported event: pause")
      expect(result[:reason]).to eq(:bad_request)
      expect(workflow.reload.human_status_name).to eq("running")
    end

    it "does not finish failed workflow", :aggregate_failures do
      workflow.drop

      result = described_class.new(workflow: workflow, current_user: user, status_event: "finish").execute

      expect(result[:status]).to eq(:error)
      expect(result[:message]).to eq("Can not finish workflow that has status failed")
      expect(result[:reason]).to eq(:bad_request)
      expect(workflow.reload.human_status_name).to eq("failed")
    end

    it "does not drop finished workflow", :aggregate_failures do
      workflow.finish

      result = described_class.new(workflow: workflow, current_user: user, status_event: "drop").execute

      expect(result[:status]).to eq(:error)
      expect(result[:message]).to eq("Can not drop workflow that has status finished")
      expect(result[:reason]).to eq(:bad_request)
      expect(workflow.reload.human_status_name).to eq("finished")
    end

    it "does not start failed workflow", :aggregate_failures do
      workflow.drop

      result = described_class.new(workflow: workflow, current_user: user, status_event: "start").execute

      expect(result[:status]).to eq(:error)
      expect(result[:message]).to eq("Can not start workflow that has status failed")
      expect(result[:reason]).to eq(:bad_request)
      expect(workflow.reload.human_status_name).to eq("failed")
    end

    it "does not allow user without permission to finish workflow", :aggregate_failures do
      result = described_class.new(workflow: workflow, current_user: another_user, status_event: "finish").execute

      expect(result[:status]).to eq(:error)
      expect(result[:message]).to eq("Can not update workflow")
      expect(result[:reason]).to eq(:unauthorized)
      expect(workflow.reload.human_status_name).to eq("running")
    end
  end
end
