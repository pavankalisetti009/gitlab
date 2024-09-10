# frozen_string_literal: true

FactoryBot.define do
  factory :project_security_exclusion, class: 'Security::ProjectSecurityExclusion' do
    scanner { 'secret_push_protection' }
    description { 'basic exclusion with a specific value to exclude from scanning' }
    type { :raw_value }
    value { '01234567890123456789-glpat'.reverse }
    active { true }
  end
end
