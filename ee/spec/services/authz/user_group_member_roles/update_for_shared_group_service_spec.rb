# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserGroupMemberRoles::UpdateForSharedGroupService, feature_category: :permissions do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:user2) { create(:user) }
  let_it_be(:group) { create(:group) }

  # access_level should be > group_group_link.group_access so users are assigned
  # group_group_link.member_role in group_group_link.shared_group instead of
  # member.member_role_id which is nil
  let_it_be(:shared_with_group) do
    create(:group, developers: [user, user2])
  end

  let_it_be(:role) { create(:member_role, :guest) }
  let_it_be_with_reload(:group_group_link) do
    create(:group_group_link, :guest, shared_group: group, shared_with_group: shared_with_group, member_role: role)
  end

  subject(:execute) do
    described_class.new(group_group_link).execute
    user.reload
    user2.reload
  end

  it 'creates UserGroupMemberRole records for each user in group_group_link.shared_with_group' do
    expect { execute }.to change {
      [
        user.user_group_member_roles.where(group: group, shared_with_group: shared_with_group,
          member_role: group_group_link.member_role).exists?,
        user2.user_group_member_roles.where(group: group, shared_with_group: shared_with_group,
          member_role: group_group_link.member_role).exists?
      ]
    }.from([false, false]).to([true, true])

    expect(Authz::UserGroupMemberRole.count).to eq(2)
  end

  context 'with existing UserGroupMemberRole records' do
    let_it_be(:old_role) { create(:member_role, :guest) }
    # user_group_member_role for user in group_group_link.shared_group through direct
    # membership. Service is expected not to update/delete this record.
    let_it_be(:in_group) do
      create(:user_group_member_role, user: user, group: group, shared_with_group: nil, member_role: old_role)
    end

    before do
      create(:user_group_member_role, user: user, group: group, shared_with_group: shared_with_group,
        member_role: old_role)
      create(:user_group_member_role, user: user2, group: group, shared_with_group: shared_with_group,
        member_role: old_role)
    end

    it 'updates member_role_id of the correct records' do
      expect { execute }.to change {
        [
          user.user_group_member_roles.where(group: group, shared_with_group: shared_with_group).first.member_role_id,
          user2.user_group_member_roles.where(group: group, shared_with_group: shared_with_group).first.member_role_id
        ]
      }.from([old_role.id, old_role.id]).to([role.id, role.id])

      expect(user.user_group_member_roles.find_by(group: group,
        shared_with_group: nil).member_role_id).to eq old_role.id
      expect(Authz::UserGroupMemberRole.count).to eq(3)
    end

    context 'when member role is removed' do
      before do
        group_group_link.update!(member_role: nil)
      end

      it 'deletes the correct records' do
        expect(user.user_group_member_roles.count).to eq 2
        expect(user2.user_group_member_roles.count).to eq 1

        execute

        expect(user.user_group_member_roles.count).to eq 1
        expect(user2.user_group_member_roles).to be_empty

        expect(Authz::UserGroupMemberRole.find(in_group.id)).not_to be_nil
      end
    end
  end
end
