# frozen_string_literal: true

FactoryBot.define do
  factory :security_attribute, class: 'Security::Attribute' do
    sequence(:name) { |n| "Test name #{n}" }
    editable_state { :locked }
    description { 'Informative description' }
    color { '#ff0000' }
  end
end
