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
end
