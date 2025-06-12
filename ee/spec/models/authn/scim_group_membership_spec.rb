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
    describe '.by_scim_group_uid' do
      let(:scim_group_uid) { SecureRandom.uuid }

      let!(:matching_membership1) { create(:scim_group_membership, scim_group_uid: scim_group_uid) }
      let!(:matching_membership2) { create(:scim_group_membership, scim_group_uid: scim_group_uid) }

      before do
        create(:scim_group_membership, scim_group_uid: SecureRandom.uuid)
      end

      it 'returns only memberships with the specified scim_group_uid' do
        result = described_class.by_scim_group_uid(scim_group_uid)

        expect(result).to contain_exactly(matching_membership1, matching_membership2)
      end

      it 'returns empty relation when no matches found' do
        result = described_class.by_scim_group_uid(SecureRandom.uuid)

        expect(result).to be_empty
      end
    end
  end
end
