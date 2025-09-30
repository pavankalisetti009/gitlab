# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ApprovalRulePolicy, feature_category: :source_code_management do
  let_it_be_with_refind(:project) { create(:project, :private) }
  let(:rule_type) { :regular }
  let_it_be(:guest) { create(:user) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }
  let_it_be(:developer) { create(:user, developer_of: project) }

  let(:user) { guest }

  subject(:permissions) { described_class.new(user, approval_rule) }

  context 'when the rule originates from project' do
    let(:approval_rule) do
      build(:merge_requests_approval_rule, :from_project,
        project: project,
        project_id: project.id,
        rule_type: rule_type
      )
    end

    context 'and the user has permission to read the project' do
      let(:user) { maintainer }

      it { is_expected.to be_allowed(:read_approval_rule) }
    end

    context 'and the user has permission to change project settings' do
      let(:user) { maintainer }

      it { is_expected.to be_allowed(:edit_approval_rule) }
    end

    context 'and the user lacks the required access level' do
      it { is_expected.not_to be_allowed(:edit_approval_rule) }
      it { is_expected.not_to be_allowed(:read_approval_rule) }
    end
  end

  context 'when the rule originates from a merge request' do
    let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

    let(:approval_rule) do
      build(:merge_requests_approval_rule, :from_merge_request, merge_request: merge_request, project_id: project.id,
        rule_type: rule_type)
    end

    context 'when approval rule is user_defined' do
      before do
        allow(approval_rule).to receive(:user_defined?).and_return(true)
      end

      context 'and user can update_approvers' do
        let(:user) { maintainer }

        it { is_expected.to be_allowed(:edit_approval_rule) }
      end

      context 'and user cannot update_approvers' do
        let(:user) { developer }

        it { is_expected.not_to be_allowed(:edit_approval_rule) }
      end
    end

    context 'when approval rule is not user_defined' do
      before do
        allow(approval_rule).to receive(:user_defined?).and_return(false)
      end

      context 'and user can update_approvers' do
        let(:user) { maintainer }

        it { is_expected.not_to be_allowed(:edit_approval_rule) }
      end

      context 'and user cannot update_approvers' do
        let(:user) { developer }

        it { is_expected.not_to be_allowed(:edit_approval_rule) }
      end
    end
  end

  context 'when the rule originates from a group' do
    let(:approval_rule) do
      build(:merge_requests_approval_rule, :from_group,
        project: project,
        project_id: project.id,
        rule_type: rule_type
      )
    end

    # TODO: Update this once group approval rules have been implemented
    it { is_expected.not_to be_allowed(:edit_approval_rule) }
    it { is_expected.not_to be_allowed(:read_approval_rule) }
  end
end
