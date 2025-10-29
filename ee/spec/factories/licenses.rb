# frozen_string_literal: true

FactoryBot.define do
  factory :license do
    transient do
      plan { nil }
      expired { false }
      trial { false }
      seats { nil }
      recently_expired { false }
    end

    data do
      traits = []
      traits << :trial if trial
      traits << :expired if expired
      traits << :cloud if cloud
      traits << :recently_expired if recently_expired

      build(:gitlab_license, *traits, plan: plan, seats: seats).export
    end

    # Disable validations when creating an expired license key
    to_create { |instance| instance.save!(validate: !expired) }

    trait :trial do
      trial { true }
    end

    trait :ultimate do
      plan { License::ULTIMATE_PLAN }
    end

    trait :ultimate_trial do
      ultimate
      trial
    end
  end
end
