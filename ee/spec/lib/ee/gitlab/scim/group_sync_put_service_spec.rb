# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Gitlab::Scim::GroupSyncPutService, feature_category: :system_access do
  let_it_be(:scim_group_uid) { SecureRandom.uuid }
  let_it_be(:group) { create(:group) }
  let_it_be(:another_group) { create(:group) }
  let_it_be(:user1) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be(:user3) { create(:user) }
  let_it_be(:regular_user) { create(:user) }
  let_it_be(:identity1) { create(:scim_identity, user: user1, extern_uid: 'scim-user1', group: nil) }
  let_it_be(:identity2) { create(:scim_identity, user: user2, extern_uid: 'scim-user2', group: nil) }
  let_it_be(:identity3) { create(:scim_identity, user: user3, extern_uid: 'scim-user3', group: nil) }

  let!(:saml_group_link) do
    create(:saml_group_link, group: group, saml_group_name: 'engineering', scim_group_uid: scim_group_uid)
  end

  let!(:another_group_link) do
    create(:saml_group_link, group: another_group, saml_group_name: 'engineering', scim_group_uid: scim_group_uid)
  end

  let(:members) { [] }
  let(:display_name) { 'Engineering' }

  subject(:service) do
    described_class.new(
      scim_group_uid: scim_group_uid,
      members: members,
      display_name: display_name
    )
  end

  describe '#execute' do
    context 'with empty members list' do
      it 'returns a success response' do
        result = service.execute

        expect(result).to be_success
      end

      context 'when groups have existing SCIM members' do
        before do
          group.add_member(user1, Gitlab::Access::DEVELOPER)
          another_group.add_member(user1, Gitlab::Access::DEVELOPER)

          create(:identity, user: user1, provider: 'scim', saml_provider: nil)
        end

        it 'enqueues removal jobs for SCIM members' do
          expect(::Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
            .with(scim_group_uid, [user1.id], 'remove')
            .once

          service.execute
        end
      end

      context 'when groups have non-SCIM members' do
        before do
          group.add_member(regular_user, Gitlab::Access::DEVELOPER)
        end

        it 'does not enqueue a job for non-SCIM members' do
          expect(::Authn::SyncScimGroupMembersWorker).not_to receive(:perform_async)
            .with(scim_group_uid, [regular_user.id], 'remove')

          service.execute
        end
      end
    end

    context 'with members list' do
      let(:members) do
        [
          { value: identity1.extern_uid },
          { value: identity2.extern_uid }
        ]
      end

      it 'enqueues a job to add the members' do
        expect(::Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
          .with(scim_group_uid, [user1.id, user2.id], 'add')
          .once

        service.execute
      end

      it 'returns a success response' do
        result = service.execute

        expect(result).to be_success
      end

      context 'with existing SCIM members not in the provided list' do
        before do
          group.add_member(user3, Gitlab::Access::DEVELOPER)
          another_group.add_member(user3, Gitlab::Access::DEVELOPER)

          create(:identity, user: user3, provider: 'scim', saml_provider: nil)
        end

        it 'enqueues a job to remove members not in the list' do
          expect(::Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
            .with(scim_group_uid, [user3.id], 'remove')
            .once

          expect(::Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
            .with(scim_group_uid, [user1.id, user2.id], 'add')
            .once

          service.execute
        end
      end

      context 'with non-existent user identity values' do
        let(:members) do
          [
            { value: 'non-existent-identity-1' },
            { value: 'non-existent-identity-2' }
          ]
        end

        context 'with existing SCIM members in the group' do
          before do
            group.add_member(user1, Gitlab::Access::DEVELOPER)

            create(:identity, user: user1, provider: 'scim', saml_provider: nil)
          end

          it 'enqueues a job to remove existing members' do
            expect(::Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
              .with(scim_group_uid, [user1.id], 'remove')
              .once

            service.execute
          end
        end

        it 'does not enqueue a job to add members when no matches found' do
          expect(::Authn::SyncScimGroupMembersWorker).not_to receive(:perform_async)
            .with(scim_group_uid, anything, 'add')

          service.execute
        end

        it 'returns a success response' do
          result = service.execute

          expect(result).to be_success
        end
      end

      context 'with case-insensitive extern_uid values' do
        let(:members) do
          [
            { value: identity1.extern_uid.upcase },
            { value: identity2.extern_uid.downcase }
          ]
        end

        it 'enqueues a job with all matching user IDs' do
          expect(::Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
            .with(scim_group_uid, [user1.id, user2.id], 'add')
            .once

          service.execute
        end
      end

      context 'with members missing the value attribute' do
        let(:members) do
          [
            { display: 'Missing' }, # Missing `value`
            { value: identity1.extern_uid, display: 'User 1' }
          ]
        end

        it 'enqueues a job with only valid member IDs' do
          expect(::Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
            .with(scim_group_uid, [user1.id], 'add')
            .once

          service.execute
        end
      end
    end
  end
end
