# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::MarkForDeletionService, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group, owners: user) }

  subject(:result) { described_class.new(group, user, {}).execute }

  before do
    stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
    stub_feature_flags(downtier_delayed_deletion: false)
  end

  context 'for audit events' do
    it 'logs audit event' do
      allow(::Gitlab::Audit::Auditor).to receive(:audit).and_call_original
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(name: 'group_deletion_marked')
      ).and_call_original

      expect { result }.to change { AuditEvent.count }.by(1)
    end
  end

  context 'when not licensed' do
    before do
      stub_licensed_features(adjourned_deletion_for_projects_and_groups: false)
    end

    it 'returns an error' do
      expect(result).to eq({ status: :error, message: 'Cannot mark group for deletion: feature not supported' })
    end

    it 'does not log an audit event' do
      expect { result }.not_to change { AuditEvent.count }
    end
  end
end
