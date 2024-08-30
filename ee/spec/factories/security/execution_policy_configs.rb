# frozen_string_literal: true

FactoryBot.define do
  factory(
    :execution_policy_config,
    class: '::Gitlab::Security::Orchestration::ExecutionPolicyConfig'
  ) do
    content { { policy_job: { script: 'echo' } }.to_yaml }
    strategy { :inject_ci }
    suffix_strategy { :on_conflict }
    suffix { ':policy-123456-0' }

    skip_create

    trait :override_project_ci do
      strategy { :override_project_ci }
    end

    trait :suffix_never do
      suffix_strategy { :never }
      suffix { nil }
    end
  end
end
