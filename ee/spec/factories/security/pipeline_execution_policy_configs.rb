# frozen_string_literal: true

FactoryBot.define do
  factory(
    :pipeline_execution_policy_config,
    class: '::Security::PipelineExecutionPolicy::Config'
  ) do
    policy factory: :pipeline_execution_policy
    policy_project_id { 123456 }
    policy_index { 0 }

    skip_create
    initialize_with do
      policy = attributes[:policy]
      policy[:content] = attributes[:content] if attributes[:content].present?
      new(policy: policy, policy_project_id: attributes[:policy_project_id], policy_index: attributes[:policy_index])
    end

    trait :override_project_ci do
      policy factory: [:pipeline_execution_policy, :override_project_ci]
    end

    trait :suffix_on_conflict do
      policy factory: [:pipeline_execution_policy, :suffix_on_conflict]
    end

    trait :suffix_never do
      policy factory: [:pipeline_execution_policy, :suffix_never]
    end
  end
end
