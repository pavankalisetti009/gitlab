# frozen_string_literal: true

FactoryBot.define do
  factory :ai_active_context_collection, class: 'Ai::ActiveContext::Collection' do
    sequence(:name) { |n| "Collection#{n}" }
    association :connection, factory: :ai_active_context_connection
  end
end
