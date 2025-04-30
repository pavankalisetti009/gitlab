# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::Ldap::AdminRolesSyncService, feature_category: :permissions do
  describe '.enqueue_sync' do
    it 'enqueues the LdapAdminRoleWorker' do
      expect(::Authz::LdapAdminRoleWorker).to receive(:perform_async)

      described_class.enqueue_sync
    end

    it 'does not raise an error when the worker is enqueued' do
      allow(::Authz::LdapAdminRoleWorker).to receive(:perform_async)

      expect { described_class.enqueue_sync }.not_to raise_error
    end
  end
end
