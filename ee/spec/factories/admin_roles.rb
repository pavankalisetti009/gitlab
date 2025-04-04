# frozen_string_literal: true

FactoryBot.define do
  factory :admin_role, class: 'Authz::AdminRole' do
    name { FFaker::Lorem.word }
    description { FFaker::Lorem.sentence }

    Gitlab::CustomRoles::Definition.admin.each_value do |attributes|
      trait attributes[:name].to_sym do
        send(attributes[:name].to_sym) { true }
      end
    end
  end
end
