# frozen_string_literal: true

FactoryBot.define do
  factory :policy_dismissal, class: 'Security::PolicyDismissal' do
    project
    merge_request
    security_policy
    user
    security_findings_uuids { [SecureRandom.uuid] }
  end
end
