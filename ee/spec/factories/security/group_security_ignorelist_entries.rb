# frozen_string_literal: true

FactoryBot.define do
  factory :group_security_ignorelist_entry, class: 'Security::GroupSecurityIgnorelistEntry' do
    scanner { 'secret_push_protection' }
    description { 'basic allowlist entry with a specific value to ignore/allow' }
    type { 'raw_value' }
    value { '01234567890123456789-glpat'.reverse }
    active { true }
  end
end
