# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::LdapAdminRoleLink, feature_category: :system_access do
  describe 'associations' do
    it { is_expected.to belong_to(:member_role) }
  end

  describe 'validation' do
    subject(:user_member_role) { build(:ldap_admin_role_link) }

    it { is_expected.to validate_presence_of(:member_role) }
    it { is_expected.to validate_presence_of(:provider) }
    it { is_expected.to validate_length_of(:provider).is_at_most(255) }
    it { is_expected.to validate_length_of(:cn).is_at_most(255) }
    it { is_expected.to validate_length_of(:filter).is_at_most(255) }
  end
end
