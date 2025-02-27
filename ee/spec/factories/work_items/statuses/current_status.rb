# frozen_string_literal: true

FactoryBot.define do
  factory :work_item_current_status, class: 'WorkItems::Statuses::CurrentStatus' do
    association :work_item
    system_defined_status_id { 1 }
  end
end
