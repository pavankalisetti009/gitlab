# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::EventPublisher, feature_category: :security_policy_management do
  describe '#publish' do
    let_it_be(:deleted_policy) { create(:security_policy) }

    let(:deleted_event) do
      instance_double('Security::PolicyDeletedEvent', data: { security_policy_id: deleted_policy.id })
    end

    subject(:publish) do
      described_class.new(
        created_policies: [],
        policies_changes: [],
        deleted_policies: [deleted_policy]
      ).publish
    end

    before do
      allow(::Gitlab::EventStore).to receive(:publish_group)

      allow(Security::PolicyDeletedEvent).to receive(:new).with(data: { security_policy_id: deleted_policy.id })
        .and_return(deleted_event)
    end

    it 'publishes events' do
      expect(::Gitlab::EventStore).to receive(:publish_group).with([deleted_event])

      publish
    end
  end
end
