# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserGroupMemberRole, feature_category: :permissions do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:group).class_name('::Group') }
    it { is_expected.to belong_to(:shared_with_group).class_name('::Group') }
    it { is_expected.to belong_to(:member_role) }
  end

  describe 'validations' do
    subject(:user_group_member_role) { build(:user_group_member_role) }

    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:member_role) }
    it { is_expected.to validate_uniqueness_of(:user).scoped_to(%i[group_id shared_with_group_id member_role_id]) }
  end

  describe '.for_user_in_group_and_shared_groups' do
    let_it_be(:user) { create(:user) }
    let_it_be(:other_user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:other_group) { create(:group) }

    let_it_be(:user_in_group) { create(:user_group_member_role, user: user, group: group) }
    let_it_be(:user_in_shared_with_group) { create(:user_group_member_role, user: user, shared_with_group: group) }
    let_it_be(:user_in_other_group) { create(:user_group_member_role, user: user, group: other_group) }
    let_it_be(:user_in_shared_with_other_group) do
      create(:user_group_member_role, user: user, shared_with_group: other_group)
    end

    let_it_be(:other_user_in_group) { create(:user_group_member_role, user: other_user, group: group) }

    subject(:results) { described_class.for_user_in_group_and_shared_groups(user, group) }

    it 'returns records only for the given user and group' do
      expect(results).to match_array([user_in_group, user_in_shared_with_group])
    end
  end

  describe '.in_shared_group' do
    let_it_be(:user) { create(:user) }
    let_it_be(:user2) { create(:user) }

    let_it_be(:shared_group) { create(:group) }
    let_it_be(:shared_with_group) { create(:group) }

    let_it_be(:other_shared_group) { create(:group) }
    let_it_be(:other_shared_with_group) { create(:group) }

    # target records
    let_it_be(:user_in_shared_group) do
      create(:user_group_member_role, user: user, group: shared_group, shared_with_group: shared_with_group)
    end

    let_it_be(:user2_in_shared_group) do
      create(:user_group_member_role, user: user2, group: shared_group, shared_with_group: shared_with_group)
    end

    # non-target records
    let_it_be(:user_in_other_shared_group) do
      create(:user_group_member_role, user: user, group: other_shared_group, shared_with_group: shared_with_group)
    end

    let_it_be(:user2_in_shared_group2) do
      create(:user_group_member_role, user: user2, group: shared_group, shared_with_group: other_shared_with_group)
    end

    subject(:results) { described_class.in_shared_group(shared_group, shared_with_group) }

    it 'returns only records that match the given shared_group and shared_with_group' do
      expect(results).to match_array([user_in_shared_group, user2_in_shared_group])
    end
  end
end
