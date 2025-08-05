# frozen_string_literal: true

FactoryBot.define do
  factory :ai_flow_trigger, class: '::Ai::FlowTrigger' do
    project
    user
    event_types { [::Ai::FlowTrigger::EVENT_TYPES[:mention]] }
    sequence(:description) { |n| "description #{n}" }
  end
end
