# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Authz::Ldap::Sync::AdminRole, feature_category: :permissions do
  include LdapHelpers

  let_it_be(:adapter) { ldap_adapter }
  let_it_be(:provider) { 'ldapmain' }
  let_it_be(:ldap_proxy) { proxy(adapter, provider) }

  let_it_be_with_reload(:user_1) { create(:user) }
  let_it_be_with_reload(:user_2) { create(:user) }
  let_it_be_with_reload(:user_3) { create(:user) } # User who disappeared from LDAP
  let_it_be_with_reload(:user_4) { create(:user) } # User with LDAP role directly assigned
  let_it_be_with_reload(:admin) { create(:admin) } # Admins should not be assigned custom admin roles
  let_it_be(:member_role) { create(:member_role, :admin) }
  let_it_be(:other_member_role) { create(:member_role, :admin) }
  let_it_be(:user_member_role) do
    create(:user_member_role, member_role: other_member_role, user: user_2, ldap: true)
  end

  let_it_be(:user_4_member_role) do
    create(:user_member_role, member_role: member_role, user: user_4, ldap: false)
  end

  let_it_be(:stale_ldap_user_member_role) do
    create(:user_member_role, member_role: member_role, user: user_3, ldap: true)
  end

  let(:ldap_group_1) do
    ldap_group_entry(%W[
      #{user_dn(user_1.username).upcase} #{user_dn(user_2.username).upcase} #{user_dn('completely_different_user')}
      #{user_dn(user_4.username)} #{user_dn(admin.username)}
    ])
  end

  before do
    allow(Gitlab::Auth::Ldap::Adapter).to receive(:new).with(provider).and_return(adapter)
    allow(EE::Gitlab::Auth::Ldap::Sync::Proxy).to receive(:new).with(provider, adapter).and_return(ldap_proxy)

    allow(Gitlab.config.ldap).to receive_messages(enabled: true)

    create(:identity, user: user_1, extern_uid: user_dn(user_1.username))
    create(:identity, user: user_2, extern_uid: user_dn(user_2.username))
    create(:identity, user: user_3, extern_uid: user_dn(user_3.username))
    create(:identity, user: admin, extern_uid: user_dn(admin.username))

    stub_ldap_config(active_directory: false)
    stub_ldap_group_find_by_cn('ldap_group1', ldap_group_1, adapter)
  end

  describe '#execute' do
    shared_examples 'syncing admin roles' do
      it 'returns true' do
        expect(sync_admin_roles).to be_truthy
      end

      it 'creates a new user member role for user who does not have any yet' do
        expect { sync_admin_roles }.to change { user_1.reload.user_member_roles.first&.member_role }
          .from(nil).to(member_role)

        expect(user_1.user_member_roles.first.ldap).to be_truthy
      end

      it 'updates existing user member role for user who has one' do
        expect { sync_admin_roles }.to change { user_2.reload.user_member_roles.first.member_role }
          .from(other_member_role).to(member_role)

        expect(user_2.user_member_roles.first.ldap).to be_truthy
      end

      it 'removes user member role for user who no longer exists in LDAP' do
        expect { sync_admin_roles }.to change { user_3.reload.user_member_roles.count }.from(1).to(0)
      end

      it 'does not create user member role for admin' do
        expect { sync_admin_roles }.not_to change { admin.reload.user_member_roles.count }
      end

      context 'when saving a new record fails' do
        before do
          allow_next_instance_of(Users::UserMemberRole) do |uar|
            allow(uar).to receive(:save).and_return(false)
          end
        end

        it 'does not create a new user member role' do
          expect { sync_admin_roles }.not_to change { user_1.reload.user_member_roles.first }
        end

        it 'logs an error' do
          expect(Gitlab::AppLogger).to receive(:error).with(/Failed to save admin role for user ID/)

          sync_admin_roles
        end
      end

      context 'when updating an existing record fails' do
        before do
          # Create a double of the user member role that will be updated
          user_member_role_double = instance_double(::Users::UserMemberRole,
            user_id: user_2.id,
            member_role_id: other_member_role.id,
            user: user_2,
            ldap: true)
          errors_double = instance_double(ActiveModel::Errors, full_messages: ['Test error'])

          # Make it return false when save is called
          allow(user_member_role_double).to receive(:member_role_id=)
          allow(user_member_role_double).to receive_messages(save: false, errors: errors_double)

          # Make existing_user_member_roles return a collection including our double
          allow_next_instance_of(described_class) do |instance|
            allow(instance).to receive(:existing_user_member_roles).and_return([user_member_role_double])
          end
        end

        it 'does not create a new user member role' do
          expect { sync_admin_roles }.not_to change { user_2.reload.user_member_roles.first }
        end

        it 'logs an error' do
          expect(Gitlab::AppLogger).to receive(:error).with(/Failed to update admin role for user ID/)

          sync_admin_roles
        end
      end
    end

    subject(:sync_admin_roles) { described_class.new(provider).execute }

    context 'when custom_admin_roles feature is enabled' do
      context 'when syncing by cn (LDAP group)' do
        let_it_be(:admin_role_link) do
          create(:ldap_admin_role_link, member_role: member_role, cn: 'ldap_group1')
        end

        it_behaves_like 'syncing admin roles'
      end

      context 'when syncing by filter' do
        let_it_be(:admin_role_link) do
          create(:ldap_admin_role_link, member_role: member_role, filter: '(a=b)', cn: nil)
        end

        before do
          allow(ldap_proxy).to receive(:dns_for_filter).with('(a=b)')
            .and_return([user_dn(user_1.username), user_dn(user_2.username)])
        end

        it_behaves_like 'syncing admin roles'
      end

      context 'when users have admin roles assigned and the link does not exist anymore' do
        let_it_be(:admin_role_link_2) do
          create(:ldap_admin_role_link, member_role: member_role, cn: 'ldap_group2')
        end

        let(:ldap_group_2) do
          ldap_group_entry(%W[#{user_dn(user_2.username).upcase}])
        end

        let_it_be(:user_member_role) do
          create(:user_member_role, member_role: other_member_role, user: user_1, ldap: true)
        end

        before do
          stub_ldap_group_find_by_cn('ldap_group2', ldap_group_2, adapter)
        end

        it 'removes all user roles for the removed link (LDAP group 1) but keeps ones for second link (LDAP group 2)' do
          sync_admin_roles

          expect(user_1.reload.user_member_roles.count).to eq(0)
          expect(user_2.reload.user_member_roles.count).to eq(1)
          expect(user_3.reload.user_member_roles.count).to eq(0)
          expect(user_4.reload.user_member_roles.count).to eq(1)
        end
      end

      context 'when multiple LDAP providers exist' do
        let_it_be(:secondary_provider) { 'ldapsecondary' }
        let_it_be(:secondary_provider_user) { create(:user) }

        before do
          # Configure multiple providers
          allow(::Gitlab::Auth::Ldap::Config).to receive(:providers).and_return([provider, secondary_provider])

          # Create identities with respective providers
          create(:identity, provider: secondary_provider, user: secondary_provider_user,
            extern_uid: user_dn(secondary_provider_user.username))

          # Create user member roles for both users with the 'other' role initially
          create(:user_member_role, member_role: other_member_role, user: secondary_provider_user, ldap: true)

          test_ldap_group = ldap_group_entry([
            user_dn(secondary_provider_user.username).upcase
          ])
          stub_ldap_group_find_by_cn('ldap_group1', test_ldap_group, adapter)
        end

        it 'do not update user of the secondary provider' do
          sync_admin_roles

          # User with non-matching provider identity should NOT have their role updated
          expect(secondary_provider_user.reload.user_member_roles.first.member_role).to eq(other_member_role)
        end
      end
    end

    context 'when custom_admin_roles feature is disabled' do
      before do
        stub_feature_flags(custom_admin_roles: false)
      end

      it 'returns false' do
        expect(sync_admin_roles).to be_falsey
      end

      it 'does not create any user member role' do
        expect { sync_admin_roles }.not_to change { user_1.reload.user_member_roles.first }
      end

      it 'does not remove any user member role' do
        expect { sync_admin_roles }.not_to change { user_3.reload.user_member_roles.count }
      end
    end
  end

  describe '.execute_all_providers' do
    before do
      allow(::Gitlab::Auth::Ldap::Config).to receive(:providers).and_return(%w[ldapmain ldapold])
    end

    it 'initiates the class for all providers' do
      admin_role_syncer = instance_double(described_class)

      expect(described_class).to receive(:new).twice.and_return(admin_role_syncer)
      expect(admin_role_syncer).to receive(:execute).twice

      described_class.execute_all_providers
    end
  end
end
