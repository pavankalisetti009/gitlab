# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalMergeRequestRulePolicy, feature_category: :source_code_management do
  let_it_be_with_refind(:project) { create(:project, :private, disable_overriding_approvers_per_merge_request: false) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }
  let_it_be(:developer) { create(:user, developer_of: project) }

  let(:user) { developer }
  let(:approval_rule) { build(:approval_merge_request_rule, merge_request: merge_request) }

  subject(:permissions) { described_class.new(user, approval_rule) }

  describe 'edit_approval_rule permission' do
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
end
