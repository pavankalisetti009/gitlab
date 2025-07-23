# frozen_string_literal: true

FactoryBot.define do
  factory :ai_catalog_item_version, class: 'Ai::Catalog::ItemVersion' do
    version { '1.0.0' }
    schema_version { 1 }
    release_date { nil }
    definition do
      {
        'system_prompt' => 'Talk like a pirate!',
        'tools' => [1],
        'user_prompt' => 'What is a leap year?'
      }
    end
    item { association :ai_catalog_item }

    trait :released do
      release_date { Time.current }
    end
  end
end
