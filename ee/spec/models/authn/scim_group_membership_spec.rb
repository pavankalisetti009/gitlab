# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authn::ScimGroupMembership, type: :model, feature_category: :system_access do
  describe 'associations' do
    it { is_expected.to belong_to(:user).optional(false) }
  end

  describe 'validations' do
    subject { build(:scim_group_membership) }

    it { is_expected.to validate_presence_of(:scim_group_uid) }
    it { is_expected.to validate_uniqueness_of(:user).scoped_to(:scim_group_uid) }
  end

  describe 'scopes' do
    let_it_be(:scim_group_uid) { SecureRandom.uuid }
    let_it_be(:another_scim_group_uid) { SecureRandom.uuid }
    let_it_be(:user1) { create(:user) }
    let_it_be(:user2) { create(:user) }

    let_it_be(:membership1) { create(:scim_group_membership, user: user1, scim_group_uid: scim_group_uid) }
    let_it_be(:membership2) { create(:scim_group_membership, user: user2, scim_group_uid: scim_group_uid) }
    let_it_be(:membership3) { create(:scim_group_membership, user: user1, scim_group_uid: another_scim_group_uid) }

    describe '.by_scim_group_uid' do
      it 'returns memberships for the specified SCIM group' do
        result = described_class.by_scim_group_uid(scim_group_uid)

        expect(result).to contain_exactly(membership1, membership2)
      end
    end

    describe '.by_user_id' do
      it 'returns memberships for the specified user' do
        result = described_class.by_user_id(user1.id)

        expect(result).to contain_exactly(membership1, membership3)
      end
    end
  end
end
