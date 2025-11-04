# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::RecreateProjectWarnModeAuditEventsWorker, feature_category: :security_policy_management do
  include_context 'with policy sync state'

  let_it_be(:project) do
    create(:project,
      merge_requests_author_approval: true,
      merge_requests_disable_committers_approval: false,
      require_password_to_approve: false)
  end

  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }

  let_it_be(:warn_mode_policy_a) do
    create(:security_policy, enabled: true,
      security_orchestration_policy_configuration: policy_configuration, policy_index: 1,
      content: { enforcement_type: Security::Policy::ENFORCEMENT_TYPE_WARN,
                 approval_settings: { prevent_approval_by_author: true } })
  end

  let_it_be(:warn_mode_policy_b) do
    create(:security_policy, enabled: true,
      security_orchestration_policy_configuration: policy_configuration, policy_index: 2,
      content: { enforcement_type: Security::Policy::ENFORCEMENT_TYPE_WARN,
                 approval_settings: { prevent_approval_by_commit_author: true } })
  end

  let_it_be(:enforced_policy) do
    create(:security_policy, enabled: true,
      security_orchestration_policy_configuration: policy_configuration, policy_index: 3,
      content: { approval_settings: { push_password_required_event: true } })
  end

  let_it_be(:policy_bot) { create(:user, :security_policy_bot) { |bot| project.add_guest(bot) } }

  let(:project_id) { project.id }
  let(:event) { Projects::MergeRequestApprovalSettingsUpdatedEvent.new(data: { project_id: project_id }) }

  subject(:handle_event) { described_class.new.handle_event(event) }

  before_all do
    Security::PolicyProjectLink.insert_all(
      Security::Policy.all.map { |policy| { security_policy_id: policy.id, project_id: project.id } })
  end

  before do
    stub_licensed_features(security_orchestration_policies: true)
  end

  shared_examples 'does not create audit events' do
    specify do
      expect(Gitlab::Audit::Auditor).not_to receive(:audit)

      handle_event
    end
  end

  context 'with valid project ID' do
    let(:audit_event) { Security::ScanResultPolicies::CreateProjectWarnModeAuditEventService::AUDIT_EVENT }

    specify do
      expect(Gitlab::Audit::Auditor)
        .to receive(:audit).with(hash_including(name: audit_event)).exactly(:twice)

      handle_event
    end

    context 'without licensed feature' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      include_examples 'does not create audit events'
    end

    context 'with feature disabled' do
      before do
        stub_feature_flags(security_policy_approval_warn_mode: false)
      end

      include_examples 'does not create audit events'
    end
  end

  context 'with invalid project ID' do
    let(:project_id) { non_existing_record_id }

    include_examples 'does not create audit events'
  end
end
