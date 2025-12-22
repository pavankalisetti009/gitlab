# frozen_string_literal: true

FactoryBot.define do
  factory :ai_namespace_feature_access_rules, class: 'Ai::NamespaceFeatureAccessRule' do
    association :through_namespace, factory: :namespace
    association :root_namespace, factory: :namespace
    accessible_entity { 'duo_classic' }
    created_at { Time.zone.now }
    updated_at { Time.zone.now }

    trait :duo_agents do
      accessible_entity { 'duo_agents' }
    end

    trait :duo_flows do
      accessible_entity { 'duo_flows' }
    end

    trait :duo_classic do
      accessible_entity { 'duo_classic' }
    end
  end
end
