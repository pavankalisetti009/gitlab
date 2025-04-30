# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::LdapAdminRoleWorker, feature_category: :permissions do
  describe '#perform' do
    subject(:perform_worker) { described_class.new.perform }

    context 'without provider argument' do
      it 'calls execute_all_providers sync class method' do
        expect(::Gitlab::Authz::Ldap::Sync::AdminRole).to receive(:execute_all_providers)

        perform_worker
      end
    end
  end
end
