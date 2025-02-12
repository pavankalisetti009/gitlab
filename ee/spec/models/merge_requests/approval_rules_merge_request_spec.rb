# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ApprovalRulesMergeRequest, type: :model, feature_category: :code_review_workflow do
  describe 'associations' do
    it { is_expected.to belong_to(:approval_rule) }
    it { is_expected.to belong_to(:merge_request) }
  end

  describe 'validations' do
    context 'when adding the same merge request to an approval rule' do
      let(:merge_request) { create(:merge_request) }
      let(:group) { create(:group) }
      let(:approval_rule) { create(:merge_requests_approval_rule, group_id: group.id) }

      before do
        create(:merge_requests_approval_rules_merge_request, approval_rule: approval_rule,
          merge_request: merge_request, project_id: merge_request.project_id)
      end

      it 'is not valid' do
        duplicate_approval_rules_merge_request = build(:merge_requests_approval_rules_merge_request,
          approval_rule: approval_rule, merge_request_id: merge_request.id, project_id: merge_request.project_id)
        expect(duplicate_approval_rules_merge_request).not_to be_valid
        expect(duplicate_approval_rules_merge_request.errors[:merge_request_id]).to include('has already been taken')
      end
    end
  end
end
