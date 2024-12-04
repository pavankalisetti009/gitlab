# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Configuration::SetGroupSecretPushProtectionWorker, feature_category: :secret_detection do
  let_it_be(:group) { create(:group) }
  let_it_be(:group_id) { group.id }

  let(:excluded_projects_ids) { [1, 2, 3] }

  describe '#perform' do
    subject(:run_worker) do
      described_class.new.perform(group_id, true, nil, excluded_projects_ids)
    end

    before do
      allow(Security::Configuration::SetNamespaceSecretPushProtectionService).to receive(:execute)
    end

    context 'when group exists' do
      it 'calls the `Security::Configuration::SetNamespaceSecretPushProtectionService` for the group' do
        run_worker

        expect(Security::Configuration::SetNamespaceSecretPushProtectionService).to have_received(:execute).with(
          { enable: true, namespace: group, excluded_projects_ids: excluded_projects_ids }
        )
      end
    end

    context 'when no such a group with group_id exists' do
      let_it_be(:group_id) { Time.now.to_i }

      it 'does not call SetNamespaceSecretPushProtectionService' do
        run_worker
        expect(Security::Configuration::SetNamespaceSecretPushProtectionService).not_to have_received(:execute)
      end
    end

    include_examples 'an idempotent worker' do
      let(:job_args) { [group.id, true, nil, excluded_projects_ids] }
    end
  end
end
