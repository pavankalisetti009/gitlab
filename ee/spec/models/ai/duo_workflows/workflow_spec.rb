# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::Workflow, feature_category: :duo_workflow do
  let(:user) { create(:user) }
  let(:another_user) { create(:user) }
  let(:owned_workflow) { create(:duo_workflows_workflow, user: user) }
  let(:not_owned_workflow) { create(:duo_workflows_workflow, user: another_user) }

  describe '.for_user_with_id!' do
    it 'finds the workflow for the given user and id' do
      expect(described_class.for_user_with_id!(user.id, owned_workflow.id)).to eq(owned_workflow)
    end

    it 'raises an error if the workflow is for a different user' do
      expect { described_class.for_user_with_id!(another_user, owned_workflow.id) }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '.for_user' do
    it 'finds the workflows for the given user' do
      expect(described_class.for_user(user)).to eq([owned_workflow])
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_length_of(:goal).is_at_most(4096) }
  end

  describe 'state transitions' do
    using RSpec::Parameterized::TableSyntax
    where(:status, :can_start, :can_pause, :can_resume, :can_finish, :can_drop) do
      0 | true  | false | false | false | true
      1 | false | true  | false | true  | true
      2 | false | false | true  | false | true
      3 | false | false | false | false | false
      4 | false | false | false | false | false
    end

    with_them do
      it 'adheres to state machine rules', :aggregate_failures do
        owned_workflow.status = status

        expect(owned_workflow.can_start?).to eq(can_start)
        expect(owned_workflow.can_pause?).to eq(can_pause)
        expect(owned_workflow.can_resume?).to eq(can_resume)
        expect(owned_workflow.can_finish?).to eq(can_finish)
        expect(owned_workflow.can_drop?).to eq(can_drop)
      end
    end
  end
end
