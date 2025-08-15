# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::LdapAllAddOnSeatSyncWorker, feature_category: :seat_cost_management do
  include LdapHelpers

  let(:worker) { described_class.new }

  describe '#perform' do
    context 'when LDAP is disabled' do
      before do
        allow(Gitlab::Auth::Ldap::Config).to receive(:enabled?).and_return(false)
      end

      it 'does not process any users' do
        expect(User).not_to receive(:ldap)
        worker.perform
      end
    end

    context 'when no active Duo add-on purchase exists' do
      before do
        allow(Gitlab::Auth::Ldap::Config).to receive(:enabled?).and_return(true)
      end

      it 'does not process any users' do
        expect(User).not_to receive(:ldap)
        worker.perform
      end
    end

    context 'when LDAP is enabled and active add-on purchase exists' do
      let(:user1) { create(:omniauth_user, :ldap, extern_uid: 'uid=user1,ou=people,dc=example,dc=com') }
      let(:user2) { create(:omniauth_user, :ldap, extern_uid: 'uid=user2,ou=people,dc=example,dc=com') }
      let(:user3) { create(:omniauth_user, :ldap, extern_uid: 'uid=user3,ou=people,dc=example,dc=com') }
      let(:users_batch) { [user1, user2, user3] }

      let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :self_managed, :duo_pro) }

      let(:duo_member_dns) do
        Set.new(['uid=user1,ou=people,dc=example,dc=com', 'uid=user2,ou=people,dc=example,dc=com'])
      end

      let(:bulk_assign_service) { instance_double(GitlabSubscriptions::Duo::BulkAssignService) }
      let(:bulk_unassign_service) { instance_double(GitlabSubscriptions::Duo::BulkUnassignService) }
      let(:provider) { 'ldapmain' }
      let(:group_cn) { 'duo_group' }
      let(:duo_add_on_groups) { [group_cn] }

      before do
        allow(Gitlab::Auth::Ldap::Config).to receive_messages(
          enabled?: true,
          providers: [provider]
        )

        fake_proxy = fake_ldap_sync_proxy(provider)
        allow(fake_proxy).to receive(:dns_for_group_cn).with(group_cn)
          .and_return(['uid=user1,ou=people,dc=example,dc=com', 'uid=user2,ou=people,dc=example,dc=com'])

        stub_ldap_config(duo_add_on_groups: [group_cn])
      end

      context 'when processing users for assignment and removal' do
        it 'processes users and calls bulk services for assignment and removal' do
          expect(GitlabSubscriptions::Duo::BulkAssignService).to receive(:new)
            .with(add_on_purchase: add_on_purchase, user_ids: [user1.id, user2.id])
            .and_return(bulk_assign_service)
          expect(bulk_assign_service).to receive(:execute)

          expect(GitlabSubscriptions::Duo::BulkUnassignService).to receive(:new)
            .with(add_on_purchase: add_on_purchase, user_ids: [user3.id])
            .and_return(bulk_unassign_service)
          expect(bulk_unassign_service).to receive(:execute)

          worker.perform
        end
      end

      context 'when no users need assignment or removal' do
        before do
          User.ldap.delete_all
        end

        it 'does not call bulk services' do
          expect(GitlabSubscriptions::Duo::BulkAssignService).not_to receive(:new)
          expect(GitlabSubscriptions::Duo::BulkUnassignService).not_to receive(:new)

          worker.perform
        end
      end

      context 'with multiple LDAP providers' do
        let(:multi_provider_dns) do
          Set.new([
            'uid=user1,ou=people,dc=provider1,dc=com',
            'uid=user2,ou=people,dc=provider2,dc=com'
          ])
        end

        let(:user1) { create(:omniauth_user, :ldap, extern_uid: 'uid=user1,ou=people,dc=provider1,dc=com') }
        let(:user2) { create(:omniauth_user, :ldap, extern_uid: 'uid=user2,ou=people,dc=provider2,dc=com') }
        let(:provider2) { 'ldapsecond' }
        let(:providers) { [provider, provider2] }

        before do
          allow(Gitlab::Auth::Ldap::Config).to receive_messages(
            enabled?: true,
            providers: providers
          )

          fake_proxy = fake_ldap_sync_proxy(provider)
          allow(fake_proxy).to receive(:dns_for_group_cn).with(group_cn)
            .and_return(['uid=user1,ou=people,dc=provider1,dc=com'])

          fake_proxy_2 = fake_ldap_sync_proxy(provider2)
          allow(fake_proxy_2).to receive(:dns_for_group_cn).with(group_cn)
            .and_return(['uid=user2,ou=people,dc=provider2,dc=com'])

          stub_ldap_config(duo_add_on_groups: [group_cn])
        end

        it 'processes users from all LDAP providers correctly' do
          expect(GitlabSubscriptions::Duo::BulkAssignService).to receive(:new)
            .with(add_on_purchase: add_on_purchase, user_ids: [user1.id, user2.id])
            .and_return(bulk_assign_service)
          expect(bulk_assign_service).to receive(:execute)

          expect(GitlabSubscriptions::Duo::BulkUnassignService).to receive(:new)
            .with(add_on_purchase: add_on_purchase, user_ids: [user3.id])
            .and_return(bulk_unassign_service)
          expect(bulk_unassign_service).to receive(:execute)

          worker.perform
        end
      end
    end
  end
end
