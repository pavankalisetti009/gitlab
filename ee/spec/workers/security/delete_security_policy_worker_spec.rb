# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::DeleteSecurityPolicyWorker, feature_category: :security_policy_management do
  describe '#perform' do
    let_it_be(:policy) { create(:security_policy) }
    let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: policy) }
    let_it_be(:license_policy) { create(:software_license_policy, approval_policy_rule: approval_policy_rule) }
    let_it_be(:violation) { create(:scan_result_policy_violation, approval_policy_rule: approval_policy_rule) }

    let_it_be(:approval_project_rule) do
      create(:approval_project_rule, approval_policy_rule_id: approval_policy_rule.id)
    end

    let_it_be(:approval_merge_request_rule) do
      create(:approval_merge_request_rule, approval_policy_rule_id: approval_policy_rule.id)
    end

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [policy.id] }
    end

    context 'when the policy type is scan execution policy' do
      let_it_be(:policy) { create(:security_policy, :scan_execution_policy) }
      let_it_be(:scan_execution_policy_rule) { create(:scan_execution_policy_rule, security_policy: policy) }

      it 'deletes the security policy and associated records' do
        expect { described_class.new.perform(policy.id) }.to change { Security::ScanExecutionPolicyRule.count }.by(-1)
          .and change { Security::Policy.count }.by(-1)
      end
    end

    context 'when the security policy exists' do
      it 'deletes the security policy and associated records' do
        expect { described_class.new.perform(policy.id) }.to change { ApprovalProjectRule.count }.by(-1)
          .and change { ApprovalMergeRequestRule.count }.by(-1)
          .and change { Security::ScanResultPolicyViolation.count }.by(-1)
          .and change { SoftwareLicensePolicy.count }.by(-1)
          .and change { Security::ApprovalPolicyRule.count }.by(-1)
          .and change { Security::Policy.count }.by(-1)
      end
    end

    context 'when the security policy does not exist' do
      it 'does not perform any deletes' do
        expect { described_class.new.perform(non_existing_record_id) }.not_to change { Security::Policy.count }
      end
    end
  end
end
