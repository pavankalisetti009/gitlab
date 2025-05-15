# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::Ldap::AdminRolesSyncService, feature_category: :permissions do
  describe '.enqueue_sync' do
    subject(:enqueue_sync) { described_class.enqueue_sync }

    it 'enqueues the LdapAdminRoleWorker' do
      expect(::Authz::LdapAdminRoleWorker).to receive(:perform_async)

      enqueue_sync
    end

    context 'with sync statuses' do
      let_it_be(:ready_sync) { create(:ldap_admin_role_link, cn: 'group1', sync_status: 'never_synced') }
      let_it_be(:running_sync) { create(:ldap_admin_role_link, cn: 'group2', sync_status: 'running') }
      let_it_be(:successful_sync) { create(:ldap_admin_role_link, cn: 'group3', sync_status: 'successful') }
      let_it_be(:failed_sync) { create(:ldap_admin_role_link, cn: 'group4', sync_status: 'failed') }

      it 'marks syncs that are not running as queued' do
        enqueue_sync

        expect(ready_sync.reload.sync_status).to eq('queued')
        expect(running_sync.reload.sync_status).to eq('running')
        expect(successful_sync.reload.sync_status).to eq('queued')
        expect(failed_sync.reload.sync_status).to eq('queued')
      end
    end

    it 'does not raise an error when the worker is enqueued' do
      allow(::Authz::LdapAdminRoleWorker).to receive(:perform_async)

      expect { enqueue_sync }.not_to raise_error
    end
  end
end
