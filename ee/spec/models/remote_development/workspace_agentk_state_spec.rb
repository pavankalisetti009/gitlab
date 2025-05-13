# frozen_string_literal: true

require "spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceAgentkState, feature_category: :workspaces do
  let(:workspace) { create(:workspace) }

  # noinspection RubyArgCount -- RubyMine thinks this is a kernel create method instead of a factory
  let_it_be(:project) { create(:project) }

  subject(:workspace_agentk_state) { build(:workspace_agentk_state, workspace: workspace, project: project) }

  describe "associations" do
    context "for belongs_to" do
      it { is_expected.to belong_to(:workspace) }
      it { is_expected.to belong_to(:project) }
    end

    context "when from factory" do
      before do
        workspace.save!
      end

      it "has correct associations from factory" do
        expect(workspace_agentk_state.workspace).to eq(workspace)
        expect(workspace_agentk_state.project).to eq(project)
      end
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:workspace_id) }
    it { is_expected.to validate_presence_of(:project_id) }
    it { is_expected.to validate_presence_of(:desired_config) }
  end
end
