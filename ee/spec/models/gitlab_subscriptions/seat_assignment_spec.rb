# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SeatAssignment, feature_category: :seat_cost_management do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:extra_dummy_record) { create(:gitlab_subscription_seat_assignment) }

  subject { build(:gitlab_subscription_seat_assignment) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace).required }
    it { is_expected.to belong_to(:user).required }
  end

  describe 'validations' do
    it { is_expected.to validate_uniqueness_of(:namespace_id).scoped_to(:user_id) }
  end

  describe 'scopes' do
    describe '.by_namespace' do
      it 'returns records filtered by namespace' do
        result = create(:gitlab_subscription_seat_assignment, namespace: namespace)

        expect(described_class.by_namespace(namespace)).to match_array(result)
      end
    end

    describe '.by_user' do
      it 'returns records filtered by namespace' do
        result = create(:gitlab_subscription_seat_assignment, user: user)

        expect(described_class.by_user(user)).to match_array(result)
      end
    end
  end

  describe '.find_by_namespace_and_user' do
    it 'returns single record by namespace and user' do
      result = create(:gitlab_subscription_seat_assignment, user: user, namespace: namespace)

      expect(described_class.find_by_namespace_and_user(namespace, user)).to eq(result)
    end
  end
end
