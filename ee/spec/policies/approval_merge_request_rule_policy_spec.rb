# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalMergeRequestRulePolicy, feature_category: :source_code_management do
  let_it_be(:merge_request) { create(:merge_request) }

  def permissions(user, approval_rule)
    described_class.new(user, approval_rule)
  end

  context 'when v2 approval rule' do
    let_it_be(:project) { create(:project) }
    let_it_be(:approval_rule) do
      create(:merge_requests_approval_rule, merge_request: merge_request, project_id: project.id)
    end

    context 'when user can update merge request' do
      it 'allows updating approval rule' do
        expect(permissions(merge_request.author, approval_rule)).to be_allowed(:edit_approval_rule)
      end

      context 'when rule is any-approval' do
        let(:approval_rule) do
          build(:merge_requests_approval_rule, rule_type: :any_approver, merge_request: merge_request)
        end

        it 'allows updating approval rule' do
          expect(permissions(merge_request.author, approval_rule)).to be_allowed(:edit_approval_rule)
        end
      end

      context 'when rule is not user editable' do
        let(:approval_rule) do
          build(:merge_requests_approval_rule, rule_type: :code_owner, merge_request: merge_request)
        end

        it 'disallows updating approval rule' do
          expect(permissions(merge_request.author, approval_rule)).to be_disallowed(:edit_approval_rule)
        end
      end
    end

    context 'when user cannot update merge request' do
      it 'disallows updating approval rule' do
        expect(permissions(create(:user), approval_rule)).to be_disallowed(:edit_approval_rule)
      end
    end
  end

  context 'when v1 approval rule' do
    let_it_be(:approval_rule) { create(:approval_merge_request_rule, merge_request: merge_request) }

    context 'when user can update merge request' do
      it 'allows updating approval rule' do
        expect(permissions(merge_request.author, approval_rule)).to be_allowed(:edit_approval_rule)
      end

      context 'when rule is any-approval' do
        let(:approval_rule) { build(:any_approver_rule, merge_request: merge_request) }

        it 'allows updating approval rule' do
          expect(permissions(merge_request.author, approval_rule)).to be_allowed(:edit_approval_rule)
        end
      end

      context 'when rule is not user editable' do
        let(:approval_rule) { create(:code_owner_rule, merge_request: merge_request) }

        it 'disallows updating approval rule' do
          expect(permissions(merge_request.author, approval_rule)).to be_disallowed(:edit_approval_rule)
        end
      end
    end

    context 'when user cannot update merge request' do
      it 'disallows updating approval rule' do
        expect(permissions(create(:user), approval_rule)).to be_disallowed(:edit_approval_rule)
      end
    end
  end
end
