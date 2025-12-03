# frozen_string_literal: true

FactoryBot.define do
  factory(
    :pipeline_execution_policy_config,
    class: '::Security::PipelineExecutionPolicy::Config'
  ) do
    policy factory: :pipeline_execution_policy
    policy_config factory: :security_orchestration_policy_configuration, security_policy_management_project_id: 123456
    policy_index { 0 }

    skip_create
    initialize_with do
      policy = attributes[:policy]
      policy[:content] = attributes[:content] if attributes[:content].present?
      policy_config = attributes[:policy_config]
      allow(policy_config).to receive(:configuration_sha).and_return(attributes[:policy_sha] || 'policy_sha')
      new(policy: policy, policy_config: policy_config, policy_index: attributes[:policy_index])
    end

    trait :override_project_ci do
      policy factory: [:pipeline_execution_policy, :override_project_ci]
    end

    trait :inject_policy do
      policy factory: [:pipeline_execution_policy, :inject_policy]
    end

    trait :suffix_on_conflict do
      policy factory: [:pipeline_execution_policy, :suffix_on_conflict]
    end

    trait :suffix_never do
      policy factory: [:pipeline_execution_policy, :suffix_never]
    end

    trait :skip_ci_allowed do
      policy factory: [:pipeline_execution_policy, :skip_ci_allowed]
    end

    trait :skip_ci_disallowed do
      policy factory: [:pipeline_execution_policy, :skip_ci_disallowed]
    end

    trait :variables_override_disallowed do
      policy factory: [:pipeline_execution_policy, :variables_override_disallowed]
    end
  end
end
