# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Security::SyncPolicyWorker, feature_category: :security_policy_management do
  let_it_be(:policy) { create(:security_policy) }

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
end
