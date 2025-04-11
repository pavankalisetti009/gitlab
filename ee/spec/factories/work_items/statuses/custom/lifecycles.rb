# frozen_string_literal: true

FactoryBot.define do
  factory :work_item_custom_lifecycle, class: 'WorkItems::Statuses::Custom::Lifecycle' do
    association :namespace
    association :default_open_status, factory: [:work_item_custom_status, :open]
    association :default_closed_status, factory: [:work_item_custom_status, :closed]
    association :default_duplicate_status, factory: [:work_item_custom_status, :duplicate]
    sequence(:name) { |n| "Custom Lifecycle #{n}" }
  end
end
