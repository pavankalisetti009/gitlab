# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::CheckpointPolicy, feature_category: :duo_workflow do
  subject(:policy) { described_class.new(current_user, checkpoint) }

  let_it_be(:checkpoint) { create(:duo_workflows_checkpoint) }
  let_it_be(:guest) { create(:user, guest_of: checkpoint.project) }
  let_it_be(:developer) { create(:user, developer_of: checkpoint.project) }
  let(:current_user) { guest }

  describe "read_duo_workflow_event" do
    context "when duo_workflow FF is disabled" do
      before do
        stub_feature_flags(duo_workflow: false)
      end

      it { is_expected.to be_disallowed(:read_duo_workflow_event) }
    end

    context "when duo_workflow FF is enabled" do
      before do
        stub_feature_flags(duo_workflow: true)
      end

      context "when user is guest" do
        it { is_expected.to be_disallowed(:read_duo_workflow_event) }
      end

      context "when user is a developer" do
        let(:current_user) { developer }

        context "when user is not workflow owner" do
          it { is_expected.to be_disallowed(:read_duo_workflow_event) }
        end

        context "when user is workflow owner" do
          before do
            checkpoint.workflow.update!(user: current_user)
          end

          it { is_expected.to be_allowed(:read_duo_workflow_event) }
        end
      end
    end
  end
end
