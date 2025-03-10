# frozen_string_literal: true

FactoryBot.define do
  factory :merge_requests_approval_rule, class: 'MergeRequests::ApprovalRule' do
    sequence(:name) { |n| "Approval Rule #{n}" }
    approvals_required { 2 }
    rule_type { 0 }

    trait :with_source_rule do
      association :source_rule, factory: :merge_requests_approval_rule
    end

    trait :from_group do
      origin { 0 }
    end

    trait :from_project do
      origin { 1 }
    end

    trait :from_merge_request do
      origin { 2 }
    end
  end
end
