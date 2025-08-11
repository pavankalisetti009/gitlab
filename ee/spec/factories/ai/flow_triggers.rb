# frozen_string_literal: true

FactoryBot.define do
  factory :ai_flow_trigger, class: '::Ai::FlowTrigger' do
    project
    user factory: :service_account
    event_types { [::Ai::FlowTrigger::EVENT_TYPES[:mention]] }
    sequence(:description) { |n| "description #{n}" }
    sequence(:config_path) { |n| "path/#{n}.yml" }
  end
end
