# frozen_string_literal: true

FactoryBot.define do
  factory :ai_catalog_item_consumer, class: 'Ai::Catalog::ItemConsumer' do
    for_agent
    enabled { true }
    locked { true }

    trait :for_agent do
      item { association :ai_catalog_agent }
    end

    trait :for_flow do
      item { association :ai_catalog_flow }
    end

    trait :for_third_party_flow do
      item { association :ai_catalog_third_party_flow }
    end
  end
end
