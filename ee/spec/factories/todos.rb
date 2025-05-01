# frozen_string_literal: true

FactoryBot.modify do
  factory :todo do
    trait :duo_core_access do
      action { Todo::DUO_CORE_ACCESS_GRANTED }
      target { user }
    end
  end
end
