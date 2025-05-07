# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authn::SyncScimGroupMembersWorker, feature_category: :system_access do
  let_it_be(:user1) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:another_group) { create(:group) }
  let_it_be(:scim_group_uid) { SecureRandom.uuid }

  let_it_be(:saml_group_link) do
    create(:saml_group_link,
      group: group,
      saml_group_name: 'engineering',
      scim_group_uid: scim_group_uid,
      access_level: Gitlab::Access::DEVELOPER)
  end

  let_it_be(:another_saml_group_link) do
    create(:saml_group_link,
      group: another_group,
      saml_group_name: 'engineering',
      scim_group_uid: scim_group_uid,
      access_level: Gitlab::Access::DEVELOPER)
  end

  it 'logs all arguments' do
    expect(described_class.loggable_arguments).to include(0, 1, 2)
  end

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [scim_group_uid, user1.id, 'add'] }
  end

  describe '#perform' do
    subject(:worker) { described_class.new }

    let(:user_ids) { [user1.id, user2.id] }

    context 'with add operation' do
      it 'adds the users to all groups' do
        expect(group.users).not_to include(user1, user2)
        expect(another_group.users).not_to include(user1, user2)

        worker.perform(scim_group_uid, user_ids, 'add')

        group.reload
        another_group.reload

        expect(group.users).to include(user1, user2)
        expect(another_group.users).to include(user1, user2)
      end

      context 'with multiple group links having different access levels' do
        before do
          create(:saml_group_link,
            group: group,
            saml_group_name: 'engineering-leads',
            scim_group_uid: scim_group_uid,
            access_level: Gitlab::Access::MAINTAINER)
        end

        it 'adds users with the highest access level' do
          worker.perform(scim_group_uid, [user1.id], 'add')

          member = group.members.find_by(user_id: user1.id)
          expect(member.access_level).to eq(Gitlab::Access::MAINTAINER)
        end
      end

      context 'when a user is already a member' do
        before do
          group.add_member(user1, Gitlab::Access::DEVELOPER)
        end

        it 'only adds the non-member user and keeps the existing user intact' do
          expect(group.member?(user1)).to be_truthy
          expect(group.member?(user2)).to be_falsey

          worker.perform(scim_group_uid, user_ids, 'add')

          expect(group.users).to include(user1, user2)
        end

        it 'does not downgrade existing higher access level' do
          group.add_member(user1, Gitlab::Access::MAINTAINER)

          worker.perform(scim_group_uid, [user1.id], 'add')

          member = group.members.find_by(user_id: user1.id)
          expect(member.access_level).to eq(Gitlab::Access::MAINTAINER)
        end

        context 'when another group link with higher access exists' do
          before do
            create(:saml_group_link,
              group: group,
              saml_group_name: 'engineering-leads',
              scim_group_uid: scim_group_uid,
              access_level: Gitlab::Access::MAINTAINER)
          end

          it 'upgrades existing lower access level' do
            worker.perform(scim_group_uid, [user1.id], 'add')

            member = group.members.find_by(user_id: user1.id)
            expect(member.access_level).to eq(Gitlab::Access::MAINTAINER)
          end
        end
      end

      context 'with non-existent user IDs' do
        it 'handles non-existent user IDs' do
          expect { worker.perform(scim_group_uid, [non_existing_record_id], 'add') }
            .not_to change { [group.members.count, another_group.members.count] }
        end
      end
    end

    context 'with remove operation' do
      before do
        group.add_member(user1, Gitlab::Access::DEVELOPER)
        group.add_member(user2, Gitlab::Access::DEVELOPER)
        another_group.add_member(user1, Gitlab::Access::DEVELOPER)
        another_group.add_member(user2, Gitlab::Access::DEVELOPER)
      end

      it 'removes the users from all groups' do
        expect(group.users).to include(user1, user2)
        expect(another_group.users).to include(user1, user2)

        worker.perform(scim_group_uid, user_ids, 'remove')

        group.reload
        another_group.reload

        expect(group.users).not_to include(user1, user2)
        expect(another_group.users).not_to include(user1, user2)
      end

      context 'with subgroup memberships' do
        let_it_be(:subgroup) { create(:group, parent: group) }

        before do
          subgroup.add_member(user1, Gitlab::Access::DEVELOPER)
        end

        it 'preserves subgroup memberships' do
          expect(subgroup.member?(user1)).to be_truthy

          worker.perform(scim_group_uid, [user1.id], 'remove')

          expect(group.member?(user1)).to be_falsey
          expect(subgroup.member?(user1)).to be_truthy
        end
      end

      context 'with non-existent user IDs' do
        it 'handles non-existent user IDs' do
          expect { worker.perform(scim_group_uid, [non_existing_record_id], 'remove') }
            .not_to change { [group.members.count, another_group.members.count] }
        end
      end
    end

    context 'with empty arrays' do
      it 'handles empty user IDs' do
        expect { worker.perform(scim_group_uid, [], 'add') }
          .not_to change { [group.members.count, another_group.members.count] }
      end
    end

    context 'with invalid operation type' do
      it 'does nothing for unknown operation types' do
        expect { worker.perform(scim_group_uid, user_ids, 'invalid_op') }
          .not_to change { [group.members.count, another_group.members.count] }
      end

      it 'does nothing for nil operation type' do
        expect { worker.perform(scim_group_uid, user_ids, nil) }
          .not_to change { [group.members.count, another_group.members.count] }
      end
    end
  end
end
