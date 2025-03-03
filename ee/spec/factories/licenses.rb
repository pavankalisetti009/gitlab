# frozen_string_literal: true

FactoryBot.define do
  factory :license do
    transient do
      plan { nil }
      expired { false }
      trial { false }
      seats { nil }
    end

    data do
      attrs = [:gitlab_license]
      attrs << :trial if trial
      attrs << :expired if expired
      attrs << :cloud if cloud

      build(*attrs, plan: plan, seats: seats).export
    end

    # Disable validations when creating an expired license key
    to_create { |instance| instance.save!(validate: !expired) }
  end
end
