# frozen_string_literal: true

FactoryBot.define do
  factory :work_item_custom_lifecycle, class: 'WorkItems::Statuses::Custom::Lifecycle' do
    association :namespace
    default_open_status { association :work_item_custom_status, :open, namespace: namespace }
    default_closed_status { association :work_item_custom_status, :closed, namespace: namespace }
    default_duplicate_status { association :work_item_custom_status, :duplicate, namespace: namespace }
    sequence(:name) { |n| "Custom Lifecycle #{n}" }
  end
end
