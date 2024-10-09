# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::SyncProjectService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be_with_refind(:security_policy) { create(:security_policy) }
  let_it_be_with_refind(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }

  let(:policy_changes) { { diff: {}, rules_diff: {} } }

  subject(:service) do
    described_class.new(security_policy: security_policy, project: project, policy_changes: policy_changes)
  end

  describe '#execute' do
    context 'when policy_changes is empty' do
      context 'when policy is disabled' do
        before do
          security_policy.update!(enabled: false)
        end

        it 'does not link the policy and rules' do
          expect { service.execute }.to not_change { Security::PolicyProjectLink.count }
            .and not_change { Security::ApprovalPolicyRuleProjectLink.count }
        end
      end

      context 'when policy is enabled' do
        it 'links policy and rules toproject' do
          expect { service.execute }.to change { Security::PolicyProjectLink.count }.from(0).to(1)
            .and change { Security::ApprovalPolicyRuleProjectLink.count }.from(0).to(1)
        end
      end
    end

    context 'when policy_changes exists' do
      let(:policy_changes) { { diff: { enabled: { from: false, to: true } }, rules_diff: {} } }

      context 'when policy is disabled' do
        let(:policy_changes) { { diff: { enabled: { from: true, to: false } }, rules_diff: {} } }

        before do
          security_policy.update!(enabled: false)
          create(:security_policy_project_link, project: project, security_policy: security_policy)
          create(:approval_policy_rule_project_link, project: project, approval_policy_rule: approval_policy_rule)
        end

        it 'unlinks the project from the security policy' do
          expect { service.execute }.to change { Security::PolicyProjectLink.count }.from(1).to(0)
        end

        it 'unlinks policy rules project if it is an approval policy' do
          expect { service.execute }.to change { Security::ApprovalPolicyRuleProjectLink.count }.from(1).to(0)
        end
      end

      context 'when policy is unscoped' do
        before do
          allow(service).to receive(:policy_unscoped?).and_return(true)

          create(:security_policy_project_link, project: project, security_policy: security_policy)
          create(:approval_policy_rule_project_link, project: project, approval_policy_rule: approval_policy_rule)
        end

        it 'unlinks the project from the security policy' do
          expect { service.execute }.to change { Security::PolicyProjectLink.count }.from(1).to(0)
        end

        it 'unlinks policy rules project if it is an approval policy' do
          expect { service.execute }.to change { Security::ApprovalPolicyRuleProjectLink.count }.from(1).to(0)
        end
      end

      context 'when policy is enabled and scoped' do
        before do
          allow(service).to receive(:policy_unscoped?).and_return(false)

          create(:approval_policy_rule_project_link, project: project, approval_policy_rule: approval_policy_rule)
        end

        context 'with deleted policy rules' do
          let(:policy_changes) do
            { diff: { enabled: { from: false, to: true } },
              rules_diff: { deleted: [{ id: approval_policy_rule.id }] } }
          end

          it 'unlinks policy rules project' do
            expect { service.execute }.to change { Security::ApprovalPolicyRuleProjectLink.count }.from(1).to(0)
          end
        end

        context 'with created policy rules' do
          let_it_be(:new_approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }

          let(:policy_changes) do
            { diff: { enabled: { from: false, to: true } },
              rules_diff: { created: [{ id: new_approval_policy_rule.id }] } }
          end

          it 'links policy rules project' do
            expect { service.execute }.to change { Security::ApprovalPolicyRuleProjectLink.count }.from(1).to(2)
          end
        end
      end
    end
  end
end
