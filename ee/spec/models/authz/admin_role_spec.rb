# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::AdminRole, feature_category: :permissions do
  describe 'associations' do
    it { is_expected.to have_many(:users) }
    it { is_expected.to have_many(:user_admin_roles) }
  end

  describe 'validation' do
    subject(:admin_role) { build(:admin_role) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }

    context 'for json schema' do
      Gitlab::CustomRoles::Definition.admin.each_key do |permission|
        context "for #{permission}" do
          it_behaves_like 'validates jsonb boolean field', permission, :permissions
        end
      end

      context 'when trying to store a member_role permission key' do
        Gitlab::CustomRoles::Definition.standard.each_key do |permission|
          context "for #{permission}" do
            it { is_expected.not_to allow_value({ permission => true }).for(:permissions) }
          end
        end
      end
    end
  end
end
