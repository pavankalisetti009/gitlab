# frozen_string_literal: true

FactoryBot.define do
  factory :security_attribute, class: 'Security::Attribute' do
    editable_state { :locked }
    name { 'Test Label' }
    description { 'Informative description' }
    color { '#ff0000' }
  end
end
