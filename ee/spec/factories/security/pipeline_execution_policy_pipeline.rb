# frozen_string_literal: true

FactoryBot.define do
  factory(
    :pipeline_execution_policy_pipeline,
    class: '::Security::PipelineExecutionPolicy::Pipeline'
  ) do
    pipeline factory: :ci_empty_pipeline
    config factory: :pipeline_execution_policy_config

    skip_create
    initialize_with do
      new(**attributes)
    end

    trait :override_project_ci do
      config factory: [:pipeline_execution_policy_config, :override_project_ci]
    end

    trait :suffix_never do
      config factory: [:pipeline_execution_policy_config, :suffix_never]
    end

    transient do
      job_script { nil }
    end

    after(:build) do |instance, evaluator|
      instance.pipeline.stages[0].statuses[0].update!(options: { script: evaluator.job_script }) if evaluator.job_script
    end
  end
end
