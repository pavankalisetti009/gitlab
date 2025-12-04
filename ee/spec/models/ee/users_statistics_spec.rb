# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UsersStatistics, feature_category: :user_management do
  # Note: Expected values in these tests are based on the factory defaults in spec/factories/users_statistics.rb
  let(:users_statistics) do
    build(:users_statistics, with_highest_role_minimal_access: 5, with_highest_role_guest_with_custom_role: 2)
  end

  describe '#billable' do
    context 'when there is a premium license' do
      before do
        create_current_license(plan: License::PREMIUM_PLAN)
      end

      it 'excludes blocked users, bots, minimal access users, and users without a group or project' do
        expect(users_statistics.billable).to eq(53)
      end
    end

    context 'when there is an ultimate license' do
      before do
        create_current_license(plan: License::ULTIMATE_PLAN)
      end

      it 'excludes blocked users, bots, guest users, users without a group or project and minimal access users' do
        expect(users_statistics.billable).to eq(50)
      end
    end
  end

  describe '#active' do
    it 'includes minimal access roles' do
      expect(users_statistics.active).to eq(83)
    end
  end

  describe '#non_billable' do
    context 'when there is a premium license' do
      before do
        create_current_license(plan: License::PREMIUM_PLAN)
      end

      it 'includes bots, minimal access users, and users without a group or project' do
        expect(users_statistics.non_billable).to eq(30)
      end
    end

    context 'when there is an ultimate license' do
      before do
        create_current_license(plan: License::ULTIMATE_PLAN)
      end

      it 'includes users without a group or project' do
        expect(users_statistics.non_billable).to eq(28)
      end
    end
  end

  describe '#non_billable_guests' do
    it 'sums only guests without an elevating custom role' do
      expect(users_statistics.non_billable_guests).to eq(3)
    end
  end

  describe '.create_current_stats!' do
    before do
      create(:user_highest_role, :minimal_access)

      allow(ApplicationRecord.connection).to receive(:transaction_open?).and_return(false)
    end

    it 'includes minimal access in current statistics values' do
      expect(described_class.create_current_stats!).to have_attributes(
        with_highest_role_minimal_access: 1
      )
    end

    it 'includes guests with custom role in current statistics values' do
      expect(described_class.create_current_stats!).to have_attributes(with_highest_role_guest_with_custom_role: 0)
    end
  end
end
