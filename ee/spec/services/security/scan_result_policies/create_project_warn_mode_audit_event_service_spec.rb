# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::CreateProjectWarnModeAuditEventService, feature_category: :security_policy_management do
  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }
  let_it_be(:project) { create(:project) }

  let_it_be(:enforced_policy_restrictive) { create_policy(1, true) }
  let_it_be(:warn_mode_policy_restrictive) { create_policy(2, true, :warn_mode) }
  let_it_be(:warn_mode_policy_permissive) { create_policy(3, false, :warn_mode) }

  let_it_be(:policy_bot) { create(:user, :security_policy_bot) { |bot| project.add_guest(bot) } }

  let(:service) { described_class.new(project, policy) }

  before_all do
    project.update!(merge_requests_author_approval: true)
  end

  subject(:execute) { service.execute }

  shared_examples 'creates audit event' do
    specify do
      expect(Gitlab::Audit::Auditor).to receive(:audit).with(service.audit_context)

      execute
    end
  end

  shared_examples 'does not create audit event' do
    specify do
      expect(Gitlab::Audit::Auditor).not_to receive(:audit)

      execute
    end
  end

  context 'with warn-mode policy' do
    context 'when policy is restrictive' do
      let(:policy) { warn_mode_policy_restrictive }

      include_examples 'creates audit event'

      context 'without policy bot' do
        before do
          policy_bot.destroy!
        end

        specify do
          expect { execute }.to change { project.security_policy_bot }.from(nil).to(instance_of(User))
        end

        include_examples 'creates audit event'
      end
    end

    context 'when policy is permissive' do
      let(:policy) { warn_mode_policy_permissive }

      include_examples 'does not create audit event'
    end
  end

  context 'with enforced policy' do
    let(:policy) { enforced_policy_restrictive }

    include_examples 'does not create audit event'
  end

  private

  def create_policy(policy_index, prevent_approval_by_author, *traits)
    build(:security_policy, *traits,
      security_orchestration_policy_configuration: policy_configuration,
      policy_index: policy_index).tap do |policy|
      policy.update!(content: policy.content.merge("approval_settings" => {
        "prevent_approval_by_author" => prevent_approval_by_author
      }))
    end
  end
end
