# frozen_string_literal: true

FactoryBot.define do
  factory :project_allowlist_entry, class: 'Security::ProjectAllowlistEntry' do
    scanner { 'secret_push_protection' }
    description { 'basic allowlist entry with a specific value to ignore/allow' }
    type { 'raw_value' }
    value { '01234567890123456789-glpat'.reverse }
    active { true }
  end
end
