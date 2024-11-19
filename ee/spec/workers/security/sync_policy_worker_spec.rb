# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Security::SyncPolicyWorker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
  let_it_be_with_reload(:policy) do
    create(:security_policy, security_orchestration_policy_configuration: policy_configuration)
  end

  context 'when event is Security::PolicyDeletedEvent' do
    let(:policy_deleted_event) do
      Security::PolicyDeletedEvent.new(data: { security_policy_id: policy.id })
    end

    it_behaves_like 'subscribes to event' do
      let(:event) { policy_deleted_event }
    end

    it 'calls Security::DeleteSecurityPolicyWorker' do
      expect(::Security::DeleteSecurityPolicyWorker).to receive(:perform_async).with(policy.id)

      described_class.new.handle_event(policy_deleted_event)
    end
  end

  context 'when event is Security::PolicyCreatedEvent' do
    let(:policy_created_event) { Security::PolicyCreatedEvent.new(data: { security_policy_id: policy.id }) }

    it_behaves_like 'subscribes to event' do
      let(:event) { policy_created_event }
    end

    it 'calls Security::SyncProjectPolicyWorker' do
      expect(::Security::SyncProjectPolicyWorker).to receive(:perform_async).with(project.id, policy.id, {})

      described_class.new.handle_event(policy_created_event)
    end

    context 'when policy is disabled' do
      before do
        policy.update!(enabled: false)
      end

      it 'does not call Security::SyncProjectPolicyWorker' do
        expect(::Security::SyncProjectPolicyWorker).not_to receive(:perform_async)

        described_class.new.handle_event(policy_created_event)
      end
    end

    context 'when policy_configuration is scoped to a namespace with multiple projects' do
      let_it_be(:namespace) { create(:namespace) }
      let_it_be(:project1) { create(:project, namespace: namespace) }
      let_it_be(:project2) { create(:project, namespace: namespace) }
      let_it_be(:policy_configuration) do
        create(:security_orchestration_policy_configuration, namespace: namespace, project: nil)
      end

      let_it_be(:policy) { create(:security_policy, security_orchestration_policy_configuration: policy_configuration) }

      it 'calls Security::SyncProjectPolicyWorker' do
        expect(::Security::SyncProjectPolicyWorker).to receive(:perform_async).once.with(project1.id, policy.id, {})
        expect(::Security::SyncProjectPolicyWorker).to receive(:perform_async).once.with(project2.id, policy.id, {})

        described_class.new.handle_event(policy_created_event)
      end
    end
  end

  context 'when event is Security::PolicyUpdatedEvent' do
    let(:event_payload) do
      {
        security_policy_id: policy.id,
        diff: { enabled: { from: false, to: true } },
        rules_diff: { created: [], updated: [], deleted: [] }
      }
    end

    let(:policy_updated_event) { Security::PolicyUpdatedEvent.new(data: event_payload) }

    it_behaves_like 'subscribes to event' do
      let(:event) { policy_updated_event }
    end

    it 'calls Security::SyncProjectPolicyWorker' do
      expect(::Security::SyncProjectPolicyWorker).to receive(:perform_async).with(project.id, policy.id,
        event_payload.deep_stringify_keys)

      described_class.new.handle_event(policy_updated_event)
    end

    context 'when policy_configuration is scoped to a namespace with multiple projects' do
      let_it_be(:namespace) { create(:namespace) }
      let_it_be(:project1) { create(:project, namespace: namespace) }
      let_it_be(:project2) { create(:project, namespace: namespace) }
      let_it_be(:policy_configuration) do
        create(:security_orchestration_policy_configuration, namespace: namespace, project: nil)
      end

      let_it_be(:policy) { create(:security_policy, security_orchestration_policy_configuration: policy_configuration) }

      it 'calls Security::SyncProjectPolicyWorker' do
        expect(::Security::SyncProjectPolicyWorker).to receive(:perform_async).once.with(project1.id, policy.id,
          event_payload.deep_stringify_keys)
        expect(::Security::SyncProjectPolicyWorker).to receive(:perform_async).once.with(project2.id, policy.id,
          event_payload.deep_stringify_keys)

        described_class.new.handle_event(policy_updated_event)
      end
    end

    context 'when policy actions is changed' do
      let(:event_payload) do
        {
          security_policy_id: policy.id,
          diff: { actions: {
            from: [{ type: 'require_approval', approvals_required: 1, user_approvers: %w[owner] }],
            to: [{ type: 'require_approval', approvals_required: 1, role_approvers: %w[owner] }]
          } },
          rules_diff: { created: [], updated: [], deleted: [] }
        }
      end

      it 'calls Security::SyncProjectPolicyWorker' do
        expect(::Security::SyncProjectPolicyWorker).to receive(:perform_async).with(project.id, policy.id,
          event_payload.deep_stringify_keys)

        described_class.new.handle_event(policy_updated_event)
      end
    end

    context 'when policy changes does not need refresh' do
      let(:event_payload) do
        {
          security_policy_id: policy.id,
          diff: { name: { from: 'Old', to: 'new' } },
          rules_diff: { created: [], updated: [], deleted: [] }
        }
      end

      it 'does not call Security::SyncProjectPolicyWorker' do
        expect(::Security::SyncProjectPolicyWorker).not_to receive(:perform_async)

        described_class.new.handle_event(policy_updated_event)
      end
    end
  end
end
