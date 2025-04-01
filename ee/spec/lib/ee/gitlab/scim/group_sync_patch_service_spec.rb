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

  let_it_be(:user) { create(:user) }
  let_it_be(:identity) { create(:scim_identity, user: user, extern_uid: 'test-extern-uid', group: nil) }

  let(:group_links) { SamlGroupLink.by_scim_group_uid(scim_group_uid) }
  let(:operations) { [] }

  subject(:service) do
    described_class.new(
      group_links: group_links,
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
              { value: identity.extern_uid }
            ]
          }
        ]
      end

      it 'adds the user to all group links' do
        expect { service.execute }.to change {
          group.users.include?(user) && another_group.users.include?(user)
        }.from(false).to(true)
      end

      it 'returns a success response' do
        result = service.execute

        expect(result).to be_success
      end

      context 'when user is already a member of the group' do
        before do
          group.add_member(user, saml_group_link.access_level)
        end

        it 'does not attempt to add the user again' do
          expect(group).not_to receive(:add_member)

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
                { value: identity.extern_uid }
              ]
            }
          ]
        end

        it 'matches operations case-insensitively' do
          expect { service.execute }.to change {
            group.users.include?(user) && another_group.users.include?(user)
          }.from(false).to(true)
        end
      end

      context 'with non-existent user identity' do
        let(:operations) do
          [
            {
              op: 'Add',
              path: 'members',
              value: [
                { value: 'non-existent-identity' }
              ]
            }
          ]
        end

        it 'does not add any users' do
          expect { service.execute }.not_to change { group.users.count }
        end

        it 'returns a success response' do
          result = service.execute

          expect(result).to be_success
        end
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

      it 'accepts the operation but does not update anything' do
        expect { service.execute }.not_to change { saml_group_link.reload.attributes }
      end

      it 'returns a success response' do
        result = service.execute

        expect(result).to be_success
      end
    end

    context 'with unsupported operation type' do
      let(:operations) do
        [
          {
            op: 'Replace',
            path: 'members',
            value: []
          }
        ]
      end

      it 'does not process the operation' do
        expect { service.execute }.not_to change { group.users.count }
      end

      it 'returns a success response' do
        result = service.execute

        expect(result).to be_success
      end
    end
  end
end
