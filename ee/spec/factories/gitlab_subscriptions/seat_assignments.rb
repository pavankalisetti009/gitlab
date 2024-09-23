# frozen_string_literal: true

FactoryBot.define do
  factory :gitlab_subscription_seat_assignment, class: 'GitlabSubscriptions::SeatAssignment' do
    namespace
    user
  end
end
