# frozen_string_literal: true

FactoryBot.define do
  factory :user_admin_role, class: 'Authz::UserAdminRole' do
    admin_role
    user
  end
end
