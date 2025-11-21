# frozen_string_literal: true

FactoryBot.define do
  factory :scim_oauth_access_token do
    group

    organization do
      association :organization if group.nil?
    end
  end
end
