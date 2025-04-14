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

  describe '.create_or_update' do
    let_it_be(:user) { create(:user) }
    let_it_be(:admin_role) { create(:member_role, :admin, name: 'Admin role') }

    subject(:create_or_update) do
      described_class.create_or_update(user: user, member_role: admin_role)
    end

    context 'when user member role record does not exist' do
      it 'creates the record' do
        expect { create_or_update }.to change { described_class.count }.by(1)

        result = described_class.last

        expect(result.user).to eq(user)
        expect(result.member_role).to eq(admin_role)
      end
    end

    context 'when user member role record exists' do
      let_it_be(:user_member_role) { create(:user_member_role, user: user) }

      it 'updates the record' do
        create_or_update

        result = user_member_role.reload

        expect(result.user).to eq(user)
        expect(result.member_role).to eq(admin_role)
      end
    end
  end
end
