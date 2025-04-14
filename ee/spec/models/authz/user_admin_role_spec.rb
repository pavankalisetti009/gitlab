# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::UserAdminRole, feature_category: :system_access do
  describe 'associations' do
    it { is_expected.to belong_to(:admin_role).class_name('Authz::AdminRole') }
    it { is_expected.to belong_to(:member_role) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'validation' do
    subject(:user_admin_role) { build(:user_admin_role) }

    it { is_expected.to validate_presence_of(:admin_role) }
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_uniqueness_of(:user) }
  end

  describe '.klass' do
    subject(:klass) { described_class.klass(build(:user)) }

    before do
      stub_feature_flags(extract_admin_roles_from_member_roles: flag_value)
    end

    context 'with :extract_admin_roles_from_member_roles flag enabled' do
      let(:flag_value) { true }

      it { is_expected.to eq(described_class) }
    end

    context 'with :extract_admin_roles_from_member_roles flag disabled' do
      let(:flag_value) { false }

      it { is_expected.to eq(Users::UserMemberRole) }
    end
  end
end
