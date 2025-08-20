# frozen_string_literal: true

FactoryBot.define do
  factory :ai_catalog_item_version, class: 'Ai::Catalog::ItemVersion' do
    version { FFaker::Number.unique.number(digits: 6).to_s.scan(/.{2}/).join('.') }
    schema_version { 1 }
    for_agent
    release_date { nil }

    factory :ai_catalog_agent_version, traits: [:for_agent]
    factory :ai_catalog_flow_version, traits: [:for_flow]

    trait :released do
      release_date { Time.current }
    end

    trait :for_agent do
      item { association :ai_catalog_agent }
      definition do
        {
          'system_prompt' => 'Talk like a pirate!',
          'tools' => [1],
          'user_prompt' => 'What is a leap year?'
        }
      end
    end

    trait :for_flow do
      item { association :ai_catalog_flow }
      definition do
        {
          'triggers' => [1],
          'steps' => [
            { 'agent_id' => 1, 'current_version_id' => 10, 'pinned_version_prefix' => nil }
          ]
        }
      end
    end

    after(:create) do |version, _|
      item = version.item
      item.latest_version = version
      item.save!
    end
  end
end
