# frozen_string_literal: true

FactoryBot.define do
  factory :pipl_user, class: 'ComplianceManagement::PiplUser' do
    association :user, factory: :user
    last_access_from_pipl_country_at { Time.current }

    trait :notified do
      initial_email_sent_at { Time.current }
    end
  end
end
