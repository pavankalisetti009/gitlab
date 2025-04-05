# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Gitlab::Scim::GroupSyncPatchService, feature_category: :system_access do
  let_it_be(:scim_group_uid) { SecureRandom.uuid }
  let_it_be(:group) { create(:group) }
  let_it_be(:saml_group_link) do
    create(:saml_group_link, group: group, saml_group_name: 'engineering', scim_group_uid: scim_group_uid)
  end

  let_it_be(:another_group) { create(:group) }
  let_it_be(:another_group_link) do
    create(:saml_group_link, group: another_group, saml_group_name: 'engineering', scim_group_uid: scim_group_uid)
  end

  let_it_be(:user1) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be(:identity1) { create(:scim_identity, user: user1, extern_uid: 'scim-user1', group: nil) }
  let_it_be(:identity2) { create(:scim_identity, user: user2, extern_uid: 'scim-user2', group: nil) }

  let(:operations) { [] }

  subject(:service) do
    described_class.new(
      scim_group_uid: scim_group_uid,
      operations: operations
    )
  end

  describe '#execute' do
    context 'with add members operation' do
      let(:operations) do
        [
          {
            op: 'Add',
            path: 'members',
            value: [
              { value: identity1.extern_uid },
              { value: identity2.extern_uid }
            ]
          }
        ]
      end

      it 'schedules the worker to add members' do
        expect(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
          .with(scim_group_uid, [user1.id, user2.id], 'add')

        service.execute
      end

      it 'returns a success response' do
        allow(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)

        result = service.execute

        expect(result).to be_success
      end

      context 'with a mix of valid and non-existent user identities' do
        let(:operations) do
          [
            {
              op: 'Add',
              path: 'members',
              value: [
                { value: identity1.extern_uid },
                { value: 'non-existent-identity' }
              ]
            }
          ]
        end

        it 'only includes valid user IDs in the worker call' do
          expect(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
            .with(scim_group_uid, [user1.id], 'add')

          service.execute
        end
      end

      context 'with case-insensitive operation matching' do
        let(:operations) do
          [
            {
              op: 'ADD',
              path: 'MEMBERS',
              value: [
                { value: identity1.extern_uid }
              ]
            }
          ]
        end

        it 'still schedules the worker correctly' do
          expect(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
            .with(scim_group_uid, [user1.id], 'add')

          service.execute
        end
      end
    end

    context 'with remove members operation' do
      let(:operations) do
        [
          {
            op: 'Remove',
            path: 'members',
            value: [
              { value: identity1.extern_uid },
              { value: identity2.extern_uid }
            ]
          }
        ]
      end

      it 'schedules the worker to remove members' do
        expect(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
          .with(scim_group_uid, [user1.id, user2.id], 'remove')

        service.execute
      end

      context 'with a mix of valid and non-existent user identities' do
        let(:operations) do
          [
            {
              op: 'Remove',
              path: 'members',
              value: [
                { value: identity1.extern_uid },
                { value: 'non-existent-identity' }
              ]
            }
          ]
        end

        it 'only includes valid user IDs in the worker call' do
          expect(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
            .with(scim_group_uid, [user1.id], 'remove')

          service.execute
        end
      end

      context 'with case-insensitive operation matching' do
        let(:operations) do
          [
            {
              op: 'REMOVE',
              path: 'MEMBERS',
              value: [
                { value: identity1.extern_uid },
                { value: identity2.extern_uid }
              ]
            }
          ]
        end

        it 'still schedules the worker correctly' do
          expect(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
            .with(scim_group_uid, [user1.id, user2.id], 'remove')

          service.execute
        end
      end
    end

    context 'with mixed add and remove operations' do
      let(:operations) do
        [
          {
            op: 'Remove',
            path: 'members',
            value: [
              { value: identity1.extern_uid }
            ]
          },
          {
            op: 'Add',
            path: 'members',
            value: [
              { value: identity2.extern_uid }
            ]
          }
        ]
      end

      it 'schedules both operations with the worker' do
        expect(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
          .with(scim_group_uid, [user1.id], 'remove')

        expect(Authn::SyncScimGroupMembersWorker).to receive(:perform_async)
          .with(scim_group_uid, [user2.id], 'add')

        service.execute
      end
    end

    context 'with externalId operation' do
      let(:operations) do
        [
          {
            op: 'Add',
            path: 'externalId',
            value: 'new-external-id'
          }
        ]
      end

      it 'does not schedule any worker' do
        expect(Authn::SyncScimGroupMembersWorker).not_to receive(:perform_async)

        service.execute
      end

      it 'returns a success response' do
        result = service.execute

        expect(result).to be_success
      end
    end
  end
end
