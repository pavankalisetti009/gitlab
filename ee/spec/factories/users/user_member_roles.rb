# frozen_string_literal: true

FactoryBot.define do
  factory :user_member_role, class: 'Users::UserMemberRole' do
    member_role
    user
  end
end
