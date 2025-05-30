# frozen_string_literal: true

FactoryBot.define do
  factory :work_item_custom_status, class: 'WorkItems::Statuses::Custom::Status' do
    sequence(:name) { |n| "Custom Status #{n}" }

    association :namespace
    open

    trait :open do
      name { FFaker::Name.unique.name }
      color { '#737278' }
      category { :to_do }
      converted_from_system_defined_status_identifier { 1 }
    end

    trait :closed do
      name { FFaker::Name.unique.name }
      color { '#108548' }
      category { :done }
      converted_from_system_defined_status_identifier { 3 }
    end

    trait :duplicate do
      name { FFaker::Name.unique.name }
      color { '#DD2B0E' }
      category { :cancelled }
      converted_from_system_defined_status_identifier { 5 }
    end
  end
end
