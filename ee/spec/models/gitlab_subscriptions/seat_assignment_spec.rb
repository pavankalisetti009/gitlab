# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SeatAssignment, feature_category: :seat_cost_management do
  subject { build(:gitlab_subscription_seat_assignment) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace).required }
    it { is_expected.to belong_to(:user).required }
  end

  describe 'validations' do
    it { is_expected.to validate_uniqueness_of(:namespace_id).scoped_to(:user_id) }
  end
end
