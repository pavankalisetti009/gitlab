# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::UserMemberRole, feature_category: :system_access do
  describe 'associations' do
    it { is_expected.to belong_to(:member_role) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'validation' do
    subject(:user_member_role) { build(:user_member_role) }

    it { is_expected.to validate_presence_of(:member_role) }
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_uniqueness_of(:user) }
  end

  describe '.ldap_synced' do
    let_it_be(:user_member_role) { create(:user_member_role) }
    let_it_be(:user_member_role_ldap) { create(:user_member_role, ldap: true) }

    subject(:ldap_synced_user_roles) do
      described_class.ldap_synced
    end

    it 'returns only records with ldap true' do
      expect(ldap_synced_user_roles).to eq([user_member_role_ldap])
    end
  end
end
