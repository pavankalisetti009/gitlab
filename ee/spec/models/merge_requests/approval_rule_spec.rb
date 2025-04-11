# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ApprovalRule, type: :model, feature_category: :code_review_workflow do
  let_it_be(:project) { create(:project) }
  let_it_be(:group) { create(:group) }
  let(:attributes) { {} }

  subject(:rule) { build(:merge_requests_approval_rule, attributes) }

  describe 'validations' do
    describe 'sharding key validation' do
      context 'with group_id' do
        let(:attributes) { { group_id: group.id } }

        it { is_expected.to be_valid }
      end

      context 'with project_id' do
        let(:attributes) { { project_id: project.id } }

        it { is_expected.to be_valid }
      end

      context 'without project_id or group_id' do
        it { is_expected.not_to be_valid }

        it 'has the correct error message' do
          rule.valid?
          expect(rule.errors[:base]).to contain_exactly("Must have either `group_id` or `project_id`")
        end
      end

      context 'with both project_id and group_id' do
        let(:attributes) { { project_id: project.id, group_id: group.id } }

        it { is_expected.not_to be_valid }

        it 'has the correct error message' do
          rule.valid?
          expect(rule.errors[:base]).to contain_exactly("Cannot have both `group_id` and `project_id`")
        end
      end
    end
  end

  describe 'associations' do
    it { is_expected.to have_many(:approval_rules_approver_users) }
    it { is_expected.to have_many(:approver_users).through(:approval_rules_approver_users).source(:user) }
  end

  describe '#approver_users' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let(:approval_rule) { create(:merge_requests_approval_rule, :from_group, group_id: group.id) }

    before do
      create(:merge_requests_approval_rules_approver_user, user: user, approval_rule: approval_rule)
    end

    it 'returns users through the approval_rules_approver_users association' do
      expect(approval_rule.approver_users).to include(user)
    end
  end

  describe '#approvers' do
    it 'returns an empty array' do
      expect(rule.approvers).to eq([])
    end
  end

  describe '#from_scan_result_policy?' do
    it 'is false' do
      expect(rule.from_scan_result_policy?).to be false
    end
  end

  describe '#report_type' do
    it 'is nil' do
      expect(rule.report_type).to be_nil
    end
  end
end
