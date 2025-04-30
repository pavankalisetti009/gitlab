# frozen_string_literal: true

FactoryBot.define do
  factory :work_item_custom_status, class: 'WorkItems::Statuses::Custom::Status' do
    sequence(:name) { |n| "Custom Status #{n}" }

    association :namespace
    open

    trait :open do
      name { 'Custom to do' }
      color { '#737278' }
      category { :to_do }
    end

    trait :closed do
      name { 'Custom done' }
      color { '#108548' }
      category { :done }
    end

    trait :duplicate do
      name { 'Custom duplicate' }
      color { '#DD2B0E' }
      category { :cancelled }
    end
  end
end
