# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::SyncPolicyEventService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:compliance_framework) { create(:compliance_framework) }

  let(:policy_scope) { { compliance_frameworks: [{ id: compliance_framework.id }] } }
  let(:security_policy) do
    create(:security_policy, scope: policy_scope)
  end

  before do
    create(:compliance_framework_project_setting,
      project: project,
      compliance_management_framework: compliance_framework
    )
  end

  subject(:execute) { described_class.new(project: project, security_policy: security_policy, event: event).execute }

  describe '#execute' do
    context 'when event is ComplianceFrameworkChangedEvent' do
      let(:event) do
        Projects::ComplianceFrameworkChangedEvent.new(data: {
          project_id: project.id,
          compliance_framework_id: compliance_framework.id,
          event_type: event_type
        })
      end

      shared_examples 'when policy scope does not match compliance_framework' do
        context 'when policy scope does not have compliance_framework' do
          let(:policy_scope) { {} }

          it 'does nothing' do
            expect { execute }.not_to change { Security::PolicyProjectLink.count }
          end
        end

        context 'when policy scope has a different compliance framework' do
          let_it_be(:other_compliance_framework) { create(:compliance_framework) }
          let(:policy_scope) { { compliance_frameworks: [{ id: other_compliance_framework.id }] } }

          it 'does nothing' do
            expect { execute }.not_to change { Security::PolicyProjectLink.count }
          end
        end
      end

      context 'when framework is added' do
        let(:event_type) { Projects::ComplianceFrameworkChangedEvent::EVENT_TYPES[:added] }

        it 'links policy to project' do
          expect { execute }.to change { Security::PolicyProjectLink.count }.by(1)

          expect(project.security_policies).to contain_exactly(security_policy)
        end

        it_behaves_like 'when policy scope does not match compliance_framework'
      end

      context 'when framework is removed' do
        let(:event_type) { Projects::ComplianceFrameworkChangedEvent::EVENT_TYPES[:removed] }

        context 'when policy is linked to the project' do
          before do
            create(:security_policy_project_link, project: project, security_policy: security_policy)
          end

          it 'unlinks policy from project' do
            expect { execute }.to change { Security::PolicyProjectLink.count }.by(-1)

            expect(project.reload.security_policies).to be_empty
          end
        end

        context 'when policy is not linked to the project' do
          it 'does nothing' do
            expect { execute }.not_to change { Security::PolicyProjectLink.count }
          end
        end

        it_behaves_like 'when policy scope does not match compliance_framework'
      end
    end
  end
end
